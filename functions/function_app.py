import azure.functions as func
from azure.cosmos import CosmosClient, exceptions, PartitionKey
from azure.storage.blob import BlobServiceClient
import json
import logging
import os
import uuid
import requests
from datetime import datetime
from typing import Dict, List, Optional
import aiohttp
import asyncio
from io import BytesIO

app = func.FunctionApp()


def get_container():
    cosmos_endpoint = os.environ.get("COSMOS_ENDPOINT")
    cosmos_key = os.environ.get("COSMOS_KEY")

    if not cosmos_endpoint or not cosmos_key:
        raise Exception("Missing Cosmos DB connection settings")

    client = CosmosClient(cosmos_endpoint, cosmos_key)

    # Create database if it doesn't exist
    database_name = os.environ.get("COSMOS_DATABASE", "cookmate")
    try:
        database = client.create_database_if_not_exists(database_name)
        logging.info(f"Database {database_name} ensured")
    except Exception as e:
        logging.error(f"Error creating database: {str(e)}")
        raise

    # Create container if it doesn't exist
    container_name = os.environ.get("COSMOS_CONTAINER", "meals")
    try:
        container = database.create_container_if_not_exists(
            id=container_name,
            partition_key=PartitionKey(path="/category"),
            offer_throughput=400,
        )
        logging.info(f"Container {container_name} ensured")
        return container
    except Exception as e:
        logging.error(f"Error creating container: {str(e)}")
        raise


def get_blob_service():
    conn_str = os.environ.get("STORAGE_CONNECTION_STRING")
    if not conn_str:
        raise Exception("Missing Storage connection string")
    return BlobServiceClient.from_connection_string(conn_str)


async def download_image(session: aiohttp.ClientSession, url: str) -> Optional[bytes]:
    try:
        async with session.get(url) as response:
            if response.status == 200:
                return await response.read()
            logging.warning(
                f"Failed to download image from {url}, status: {response.status}"
            )
            return None
    except Exception as e:
        logging.error(f"Error downloading image from {url}: {str(e)}")
        return None


async def upload_to_blob_storage(image_data: bytes, recipe_id: str) -> Optional[str]:
    try:
        blob_service = get_blob_service()
        container_name = "recipe-images"
        # Create container if it doesn't exist
        try:
            blob_service.create_container(container_name)
        except Exception:
            pass  # Container already exists

        blob_name = f"{recipe_id}.jpg"
        blob_client = blob_service.get_blob_client(
            container=container_name, blob=blob_name
        )

        blob_client.upload_blob(image_data, overwrite=True)
        return blob_client.url
    except Exception as e:
        logging.error(f"Error uploading to blob storage: {str(e)}")
        return None


def map_difficulty(time_minutes: int) -> str:
    if time_minutes <= 20:
        return "Easy"
    elif time_minutes <= 45:
        return "Medium"
    else:
        return "Hard"


def extract_ingredients(extended_ingredients: List[Dict]) -> List[Dict]:
    return [
        {
            "name": ingredient.get("name", ""),
            "amount": str(ingredient.get("amount", 0)),
            "unit": ingredient.get("unit", ""),
        }
        for ingredient in extended_ingredients
    ]


def extract_instructions(analyzed_instructions: List[Dict]) -> List[str]:
    steps = []
    for instruction in analyzed_instructions:
        for step in instruction.get("steps", []):
            steps.append(step.get("step", ""))
    return steps


def map_recipe_to_schema(
    spoonacular_recipe: Dict, image_url: Optional[str] = None
) -> Dict:
    recipe_id = str(uuid.uuid4())

    return {
        "id": recipe_id,
        "name": spoonacular_recipe.get("title", ""),
        "description": spoonacular_recipe.get("summary", ""),
        "imageUrl": image_url,
        "cookingTime": spoonacular_recipe.get("readyInMinutes", 0),
        "prepTimeMinutes": spoonacular_recipe.get("preparationMinutes", 0),
        "cookTimeMinutes": spoonacular_recipe.get("cookingMinutes", 0),
        "difficulty": map_difficulty(spoonacular_recipe.get("readyInMinutes", 30)),
        "servings": spoonacular_recipe.get("servings", 1),
        "calories": spoonacular_recipe.get("nutrition", {})
        .get("nutrients", [{}])[0]
        .get("amount", 0),
        "chefName": "Spoonacular",
        "rating": float(spoonacular_recipe.get("spoonacularScore", 0))
        / 20.0,  # Convert to 5-star scale
        "reviewCount": spoonacular_recipe.get("aggregateLikes", 0),
        "ingredients": extract_ingredients(
            spoonacular_recipe.get("extendedIngredients", [])
        ),
        "instructions": extract_instructions(
            spoonacular_recipe.get("analyzedInstructions", [])
        ),
        "tags": spoonacular_recipe.get("dishTypes", [])
        + spoonacular_recipe.get("diets", []),
        "aiTips": None,
        "createdAt": datetime.utcnow().isoformat(),
        "category": spoonacular_recipe.get("dishTypes", ["Main Course"])[0],
        "cuisineType": (
            spoonacular_recipe.get("cuisines", ["International"])[0]
            if spoonacular_recipe.get("cuisines")
            else "International"
        ),
        "isFavorite": False,
    }


@app.function_name("GetMeal")
@app.route(route="GetMeal", methods=["GET"])
def get_meal(req: func.HttpRequest) -> func.HttpResponse:
    try:
        meal_id = req.params.get("id")
        if not meal_id:
            return func.HttpResponse("Please provide a meal id", status_code=400)

        container = get_container()
        query = f"SELECT * FROM c WHERE c.id = '{meal_id}'"
        items = list(
            container.query_items(query=query, enable_cross_partition_query=True)
        )

        if not items:
            return func.HttpResponse("Meal not found", status_code=404)

        return func.HttpResponse(json.dumps(items[0]), mimetype="application/json")

    except Exception as e:
        logging.error(f"Error retrieving meal: {str(e)}")
        return func.HttpResponse(f"Error retrieving meal: {str(e)}", status_code=500)


@app.function_name("CreateMeal")
@app.route(route="meals", methods=["POST"])
def create_meal(req: func.HttpRequest) -> func.HttpResponse:
    try:
        # Get the request body
        req_body = req.get_json()

        # Validate required fields
        required_fields = [
            "name",
            "ingredients",
            "instructions",
            "cookingTime",
            "servings",
            "category",
            "difficulty",
        ]
        for field in required_fields:
            if field not in req_body:
                return func.HttpResponse(
                    f"Missing required field: {field}", status_code=400
                )

        # Create new meal document with UUID
        new_meal = {
            "id": str(uuid.uuid4()),
            "name": req_body["name"],
            "ingredients": req_body["ingredients"],
            "instructions": req_body["instructions"],
            "cookingTime": req_body["cookingTime"],
            "servings": req_body["servings"],
            "category": req_body["category"],
            "difficulty": req_body["difficulty"],
            "calories": req_body.get("calories"),
            "createdAt": datetime.utcnow().isoformat(),
            "rating": 0,
            "reviews": 0,
            "imageUrl": None,  # To be implemented with Azure Storage
        }

        # Get container (this will create database and container if they don't exist)
        container = get_container()

        # Insert into database
        response = container.create_item(body=new_meal)
        logging.info(f"Created meal with id: {response['id']}")

        return func.HttpResponse(
            json.dumps(response), status_code=201, mimetype="application/json"
        )

    except ValueError as ve:
        logging.error(f"Invalid request body: {str(ve)}")
        return func.HttpResponse("Invalid request body", status_code=400)
    except Exception as e:
        logging.error(f"Error creating meal: {str(e)}")
        return func.HttpResponse(f"Error creating meal: {str(e)}", status_code=500)


# First import_recipes function removed as it's replaced by the complete one below


@app.function_name("ImportRecipes")
@app.route(route="ImportRecipes", methods=["POST"])
async def import_recipes(req: func.HttpRequest) -> func.HttpResponse:
    try:
        api_key = os.environ.get("SPOONACULAR_API_KEY")
        if not api_key:
            raise Exception("Missing Spoonacular API key")

        # Get number of recipes to import from request body or use default
        req_body = req.get_json() if req.get_body() else {}
        number_of_recipes = min(req_body.get("number", 50), 50)  # Cap at 50 recipes

        # Fetch recipes from Spoonacular
        spoonacular_url = f"https://api.spoonacular.com/recipes/random?number={number_of_recipes}&apiKey={api_key}"
        response = requests.get(spoonacular_url)

        if response.status_code != 200:
            raise Exception(f"Spoonacular API error: {response.status_code}")

        recipes_data = response.json().get("recipes", [])
        if not recipes_data:
            return func.HttpResponse(
                "No recipes returned from Spoonacular", status_code=404
            )

        # Process recipes and upload images
        cosmos_container = get_container()
        processed_recipes = []
        skipped_duplicates = 0

        # Get existing recipe names to check for duplicates
        existing_recipes_query = "SELECT c.name FROM c"
        existing_recipes = {
            item["name"]
            for item in cosmos_container.query_items(
                query=existing_recipes_query, enable_cross_partition_query=True
            )
        }

        async with aiohttp.ClientSession() as session:
            for recipe in recipes_data:
                try:
                    recipe_name = recipe.get("title")
                    if recipe_name in existing_recipes:
                        logging.info(f"Skipping duplicate recipe: {recipe_name}")
                        skipped_duplicates += 1
                        continue

                    # Download and upload image
                    image_url = recipe.get("image")
                    blob_url = None
                    if image_url:
                        image_data = await download_image(session, image_url)
                        if image_data:
                            recipe_id = str(uuid.uuid4())
                            blob_url = await upload_to_blob_storage(
                                image_data, recipe_id
                            )

                    # Map and store recipe
                    mapped_recipe = map_recipe_to_schema(recipe, blob_url)
                    cosmos_container.create_item(body=mapped_recipe)
                    processed_recipes.append(
                        {"id": mapped_recipe["id"], "name": mapped_recipe["name"]}
                    )
                    existing_recipes.add(
                        recipe_name
                    )  # Add to set to prevent duplicates within this batch

                except Exception as e:
                    logging.error(
                        f"Error processing recipe {recipe.get('title')}: {str(e)}"
                    )
                    continue

        return func.HttpResponse(
            json.dumps(
                {
                    "message": f"Successfully imported {len(processed_recipes)} recipes. Skipped {skipped_duplicates} duplicates.",
                    "recipes": processed_recipes,
                }
            ),
            mimetype="application/json",
            status_code=200,
        )

    except Exception as e:
        logging.error(f"Error importing recipes: {str(e)}")
        return func.HttpResponse(f"Error importing recipes: {str(e)}", status_code=500)


def extract_calories_from_description(description: str) -> Optional[int]:
    if not description:
        return None

    # Common patterns for calorie information
    patterns = [
        r"(\d+)\s*calories?",  # "400 calories" or "400 calorie"
        r"(\d+)\s*kcals?",  # "400 kcal" or "400 kcals"
        r"(\d+)\s*cal\b",  # "400 cal"
    ]

    import re

    for pattern in patterns:
        match = re.search(pattern, description.lower())
        if match:
            try:
                return int(match.group(1))
            except ValueError:
                continue
    return None


@app.function_name(name="GetPaginatedMeals")
@app.route(route="GetPaginatedMeals", methods=["GET"])
def get_paginated_meals(req: func.HttpRequest) -> func.HttpResponse:
    try:
        # Get pagination parameters
        page_size = int(req.params.get("pageSize", "15"))
        continuation_token = req.params.get("continuationToken")
        category = req.params.get("category")

        container = get_container()

        # Build the query based on whether a category is specified
        if category and category != "All Recipes":
            # Use LOWER() for case-insensitive comparison
            query = """
                SELECT * FROM c 
                WHERE LOWER(c.category) = LOWER(@category) 
                ORDER BY c.createdAt DESC
            """
            parameters = [{"name": "@category", "value": category}]
        else:
            query = "SELECT * FROM c ORDER BY c.createdAt DESC"
            parameters = []

        # Execute query with pagination
        if continuation_token:
            items = list(
                container.query_items(
                    query=query,
                    parameters=parameters,
                    enable_cross_partition_query=True,
                    max_item_count=page_size,
                    continuation_token=continuation_token,
                )
            )
        else:
            items = list(
                container.query_items(
                    query=query,
                    parameters=parameters,
                    enable_cross_partition_query=True,
                    max_item_count=page_size,
                )
            )

        # Process items to extract calories from description if not already present
        for item in items:
            if not item.get("calories") and item.get("description"):
                calories = extract_calories_from_description(item["description"])
                if calories:
                    item["calories"] = calories

        # Get the new continuation token
        new_continuation_token = container.client_connection.last_response_headers.get(
            "x-ms-continuation"
        )

        # Get categories and their counts
        # First get unique categories
        categories_query = (
            "SELECT DISTINCT VALUE c.category FROM c WHERE c.category != null"
        )
        categories = list(
            container.query_items(
                query=categories_query, enable_cross_partition_query=True
            )
        )

        # Then get count for each category
        category_counts = []
        for cat in categories:
            count_query = "SELECT VALUE COUNT(1) FROM c WHERE c.category = @category"
            count_params = [{"name": "@category", "value": cat}]
            count = list(
                container.query_items(
                    query=count_query,
                    parameters=count_params,
                    enable_cross_partition_query=True,
                )
            )[0]
            category_counts.append({"category": cat, "count": count})

        return func.HttpResponse(
            json.dumps(
                {
                    "items": items,
                    "categories": categories,
                    "categoryCounts": category_counts,
                    "continuationToken": new_continuation_token,
                }
            ),
            mimetype="application/json",
        )

    except Exception as e:
        logging.error(f"Error retrieving meals: {str(e)}")
        return func.HttpResponse(f"Error retrieving meals: {str(e)}", status_code=500)

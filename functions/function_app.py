import azure.functions as func
from azure.cosmos import CosmosClient, exceptions, PartitionKey
import json
import logging
import os
import uuid
from datetime import datetime

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
            offer_throughput=400
        )
        logging.info(f"Container {container_name} ensured")
        return container
    except Exception as e:
        logging.error(f"Error creating container: {str(e)}")
        raise

app = func.FunctionApp()

@app.route(route="GetMeal", methods=["GET"])
def get_meal(req: func.HttpRequest) -> func.HttpResponse:
    try:
        meal_id = req.params.get('id')
        if not meal_id:
            return func.HttpResponse(
                "Please provide a meal id",
                status_code=400
            )

        container = get_container()
        query = f"SELECT * FROM c WHERE c.id = '{meal_id}'"
        items = list(container.query_items(query=query, enable_cross_partition_query=True))

        if not items:
            return func.HttpResponse(
                "Meal not found",
                status_code=404
            )

        return func.HttpResponse(
            json.dumps(items[0]),
            mimetype="application/json"
        )

    except Exception as e:
        logging.error(f"Error retrieving meal: {str(e)}")
        return func.HttpResponse(
            f"Error retrieving meal: {str(e)}",
            status_code=500
        )

@app.route(route="meals", methods=["POST"])
def create_meal(req: func.HttpRequest) -> func.HttpResponse:
    try:
        # Get the request body
        req_body = req.get_json()
        
        # Validate required fields
        required_fields = ['name', 'ingredients', 'instructions', 'cookingTime', 'servings', 'category', 'difficulty']
        for field in required_fields:
            if field not in req_body:
                return func.HttpResponse(
                    f"Missing required field: {field}",
                    status_code=400
                )
        
        # Create new meal document with UUID
        new_meal = {
            "id": str(uuid.uuid4()),
            "name": req_body['name'],
            "ingredients": req_body['ingredients'],
            "instructions": req_body['instructions'],
            "cookingTime": req_body['cookingTime'],
            "servings": req_body['servings'],
            "category": req_body['category'],
            "difficulty": req_body['difficulty'],
            "calories": req_body.get('calories'),
            "createdAt": datetime.utcnow().isoformat(),
            "rating": 0,
            "reviews": 0,
            "imageUrl": None  # To be implemented with Azure Storage
        }
        
        # Get container (this will create database and container if they don't exist)
        container = get_container()
        
        # Insert into database
        response = container.create_item(body=new_meal)
        logging.info(f"Created meal with id: {response['id']}")
        
        return func.HttpResponse(
            json.dumps(response),
            status_code=201,
            mimetype="application/json"
        )
        
    except ValueError as ve:
        logging.error(f"Invalid request body: {str(ve)}")
        return func.HttpResponse(
            "Invalid request body",
            status_code=400
        )
    except Exception as e:
        logging.error(f"Error creating meal: {str(e)}")
        return func.HttpResponse(
            f"Error creating meal: {str(e)}",
            status_code=500
        )
import azure.functions as func
from azure.cosmos import CosmosClient, exceptions
import json
import logging
import os

app = func.FunctionApp()

@app.route(route="GetMeal", auth_level=func.AuthLevel.ANONYMOUS)
def GetMeal(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    try:
        # Get Cosmos DB connection details from app settings
        cosmos_endpoint = os.environ.get("COSMOS_ENDPOINT")
        cosmos_key = os.environ.get("COSMOS_KEY")
        
        if not cosmos_endpoint or not cosmos_key:
            logging.error("Missing Cosmos DB connection settings")
            return func.HttpResponse(
                "Server configuration error",
                status_code=500
            )

        logging.info('Connecting to Cosmos DB...')
        client = CosmosClient(cosmos_endpoint, cosmos_key)
        
        # List all databases to help with debugging
        databases = list(client.list_databases())
        for db in databases:
            logging.info(f'Found database: {db["id"]}')
            containers = list(client.get_database_client(db["id"]).list_containers())
            for container in containers:
                logging.info(f'Found container in {db["id"]}: {container["id"]}')

        # Use the first available database and container
        if not databases:
            logging.error("No databases found")
            return func.HttpResponse(
                "No databases found",
                status_code=500
            )

        database = client.get_database_client(databases[0]["id"])
        containers = list(database.list_containers())
        
        if not containers:
            logging.error("No containers found")
            return func.HttpResponse(
                "No containers found",
                status_code=500
            )

        container = database.get_container_client(containers[0]["id"])
        
        # Get meal id from query parameters
        meal_id = req.params.get('id')
        logging.info(f'Received meal_id: {meal_id}')
        
        if not meal_id:
            try:
                req_body = req.get_json()
                meal_id = req_body.get('id')
            except ValueError:
                pass

        if not meal_id:
            return func.HttpResponse(
                "Please pass a meal id in the query string or request body",
                status_code=400
            )

        # Query the meal
        query = "SELECT * FROM c WHERE c.mealsID = @id"
        parameters = [{"name": "@id", "value": meal_id}]
        
        logging.info(f'Querying with parameters: {parameters}')
        items = list(container.query_items(
            query=query,
            parameters=parameters,
            enable_cross_partition_query=True
        ))

        if not items:
            return func.HttpResponse(
                f"Meal not found with id: {meal_id}",
                status_code=404
            )

        # Return the first matching meal
        return func.HttpResponse(
            json.dumps(items[0]),
            mimetype="application/json",
            status_code=200
        )

    except exceptions.CosmosHttpResponseError as ce:
        logging.error(f"Cosmos DB error: {str(ce)}")
        return func.HttpResponse(
            f"Database error: {str(ce)}",
            status_code=500
        )
    except Exception as e:
        logging.error(f"Unexpected error: {str(e)}")
        return func.HttpResponse(
            f"An unexpected error occurred: {str(e)}",
            status_code=500
        )
# BRADIX Master Agentic API and Script Trigger System

This repository contains the FastAPI application for the BRADIX Master Agentic API and Script Trigger system. It is designed to automate various actions related to asset recovery, financial management, and communication.

## Project Structure

- `main.py`: FastAPI application with endpoints for executing actions, sending emails, making calls, checking status, and handling controversial situations.
- `config.py`: Configuration file for credentials such as SMTP, Vapi, and Telegram.
- `actions/`: Directory containing Python modules for specific actions:
  - `email_actions.py`: Handles sending various pre-defined emails.
  - `phone_actions.py`: Integrates with Vapi for automated phone calls.
  - `recovery_actions.py`: Contains logic for PPSR searches, demand letters, and accounting requests.
- `handlers/`: Directory containing Python modules for specific handlers:
  - `controversial.py`: Provides pre-built solutions for handling sensitive situations.
  - `notifications.py`: Manages Telegram bot notifications after each action.
- `templates/`: Directory containing ready-to-send markdown templates for emails and letters.
- `n8n/workflows.json`: n8n workflow definitions for automation.
- `requirements.txt`: Python dependencies for the project.
- `Dockerfile`: Dockerfile for building the FastAPI application image.
- `docker-compose.yml`: Docker Compose file for easy deployment.

## Setup and Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/toronto192020/Bradyx.git
    cd Bradyx/bradix-master-api
    ```

2.  **Configure credentials:**
    Edit `config.py` with your SMTP, Vapi, and Telegram bot credentials.

3.  **Build and run with Docker Compose:**
    ```bash
    docker-compose up --build
    ```

    Alternatively, you can build and run manually:

    **Build Docker image:**
    ```bash
    docker build -t bradix-master-api .
    ```

    **Run Docker container:**
    ```bash
    docker run -p 8000:8000 bradix-master-api
    ```

4.  **Install Python dependencies (if not using Docker):**
    ```bash
    pip install -r requirements.txt
    ```

5.  **Run the FastAPI application (if not using Docker):**
    ```bash
    uvicorn main:app --host 0.0.0.0 --port 8000
    ```

## API Endpoints

-   **`POST /execute-all`**: Runs all defined actions in sequence.
-   **`POST /send-email/{action_id}`**: Sends a specific email based on the `action_id`.
-   **`POST /make-call/{action_id}`**: Triggers a Vapi phone call based on the `action_id`.
-   **`GET /status`**: Shows the status of all tasks (currently a placeholder).
-   **`GET /controversial`**: Shows all controversial situations with pre-built solutions.

## n8n Workflows

The `n8n/workflows.json` file contains definitions for n8n automation workflows that can be imported into your n8n instance to trigger these API endpoints based on various events.

## Contributing

Feel free to fork the repository, make improvements, and submit pull requests.

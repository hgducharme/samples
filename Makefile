# -------------------------------------- #
# User defined variables
# -------------------------------------- #
DOCKER_BUILD_ARGUMENTS := ./.envs/.docker_build_args
DOCKER_COMPOSE_DEV_FILE := docker-compose.dev.yml
DOCKER_COMPOSE_PROD_FILE := docker-compose.prod.yml
DOCKER_COMPOSE_DEBUG_FILE := docker-compose.debugpy.yml 
DOCKER_COMPOSE_WIP_FILE := docker-compose.wip.yml

.DEFAULT_GOAL := help

##@
##@ Environments (required if using docker commands)
##@

.PHONY: dev prod wip

dev: ##@ Use the development environment
	@if [ "$(MAKECMDGOALS)" = "dev" ]; then \
	   echo ""; \
		echo "Error: Please specify a target (e.g., 'make dev build'). Run 'make help' to see the list of targets."; \
		exit 1; \
	fi
	$(eval ENVIRONMENT=dev)
	$(eval COMPOSE_FILE=$(DOCKER_COMPOSE_DEV_FILE))
	$(eval ENV_FILE=$(DOCKER_BUILD_ARGUMENTS))
	$(info )
	$(info Using development environment...)
	$(info docker compose file: $(COMPOSE_FILE))
	$(info .env file: $(ENV_FILE))
	@:

prod: ##@ Use the production environment
	@if [ "$(MAKECMDGOALS)" = "prod" ]; then \
		echo ""; \
		echo "Error: Please specify a target (e.g., 'make prod build'). Run 'make help' to see the list of targets."; \
		exit 1; \
	fi
	@if [ "$(MAKECMDGOALS)" = "prod debug" ]; then \
		echo ""; \
		echo "Error: The 'debug' target can only be used with the dev environment"; \
		exit 1; \
	fi
	@echo
	$(eval ENVIRONMENT=prod)
	$(eval COMPOSE_FILE=$(DOCKER_COMPOSE_PROD_FILE))
	$(eval ENV_FILE=$(DOCKER_BUILD_ARGUMENTS))
	$(info )
	$(info Using production environment...)
	$(info docker compose file: $(COMPOSE_FILE))
	$(info .env file: $(ENV_FILE))
	@:

# TODO: this shouldn't actually exist. This is just a temporary convenience function. Delete this
wip: ##@ Use the new WIP docker files
	@if [ "$(MAKECMDGOALS)" = "wip" ]; then \
	   echo ""; \
		echo "Error: Please specify a target (e.g., 'make $(MAKECMDGOALS) build'). Run 'make help' to see the list of targets."; \
		exit 1; \
	fi
	$(eval ENVIRONMENT=wip)
	$(eval COMPOSE_FILE=$(DOCKER_COMPOSE_WIP_FILE))
	$(eval ENV_FILE=$(DOCKER_BUILD_ARGUMENTS))
	$(info )
	$(info Using wip environment...)
	$(info docker compose file: $(COMPOSE_FILE))
	$(info .env file: $(ENV_FILE))
	@:


##@
##@ docker-compose (requires docker daemon to already be running)
##@

.PHONY: build build-no-cache up down debug config logs enter restart ASSERT_ENVIRONMENT

# This will ensure that a dev or prod environment is specified before running docker commands
ASSERT_ENVIRONMENT:
	@if [ -z "$(COMPOSE_FILE)" ] || [ -z "$(ENV_FILE)" ]; then \
		echo ""; \
		echo "Error: Please specify an environment (e.g. 'dev' or 'prod')."; \
		exit 1; \
	fi

build: ##@ Build docker containers
build: ASSERT_ENVIRONMENT
	@echo
	@echo "Starting build..."
	@echo
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build

build-no-cache: ##@ Build without using cached files
build-no-cache: ASSERT_ENVIRONMENT
	@echo
	@echo "Starting build with no cache..."
	@echo
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build --no-cache

up:  ##@ Start up docker containers
up: ASSERT_ENVIRONMENT
	@echo
	@echo "Spinning up containers..."
	@echo
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d

down: ##@ Take down docker containers
down: ASSERT_ENVIRONMENT
	@echo
	@echo "Taking down containers..."
	@echo
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down -v

debug: ##@ Start up the dev environment with debugpy on the django server. You must connect a debug client for the server to run!
debug: ASSERT_ENVIRONMENT
	@echo
	@echo "Spinning up the dev environment with debugging enabled..."
	@echo
	@rm -rf ./logs/debugpy
	@docker compose -f $(DOCKER_COMPOSE_DEV_FILE) -f $(DOCKER_COMPOSE_DEBUG_FILE) --env-file $(ENV_FILE) up -d

debug-restart: ##@ Restart the dev environment with debugpy on the django server
debug-restart: ASSERT_ENVIRONMENT
	@echo
	@echo "Restarting the dev environment with debugging enabled..."
	@echo
	@$(MAKE) dev down && $(MAKE) dev debug && $(MAKE) dev logs

config: ##@ Print the parsed docker-compose file
config: ASSERT_ENVIRONMENT
	@echo
	@echo "Printing parsed yaml..."
	@echo
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) config

logs: ##@ Follow the docker container logs
logs: ASSERT_ENVIRONMENT
	@echo
	@echo "Printing logs..."
	@echo
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs --follow || true

enter: ##@ Enter the shell of the running 'web' container
enter: ASSERT_ENVIRONMENT
	@echo
	@echo "Starting shell for 'web' container..."
	@echo
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec -it web bash

restart: ##@ Restart the docker containers
restart: ASSERT_ENVIRONMENT
	@echo
	@echo "Restarting containers..."
	@echo
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) restart

##@
##@ Django commands inside Docker
##@

.PHONY: collectstatic migrate

collectstatic: ##@ Run collectstatic in the docker container
collectstatic: ASSERT_ENVIRONMENT
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec web python manage.py collectstatic --no-input --clear

makemigrations: ##@ Run 'makemigrations' in the docker container
makemigrations: ASSERT_ENVIRONMENT
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec web python manage.py makemigrations

migrate: ##@ Run 'migrate' in the docker container
migrate: ASSERT_ENVIRONMENT
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec web python manage.py migrate

migratefull: ##@ Run 'makemigrations' and 'migrate' in the docker container
migratefull: ASSERT_ENVIRONMENT
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec web python manage.py makemigrations
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec web python manage.py migrate

##@
##@ Local Django commands
##@

.PHONY: local-env local-migrate local-server local-flush local-superuser local-requirements

local-env: ##@ Sets up a local development environment
	@echo
	@echo "Building a local development environment without docker..."
	@echo

	@python3 -m venv venv/ && \
	source ./venv/bin/activate && \
	pip install --upgrade pip && \
	set -a && \
	source $(DOCKER_BUILD_ARGUMENTS) && \
	set +a && \
	pip3 install -r app/requirements.txt

local-requirements: ##@ Install requirements.txt
	@echo
	@echo "Installing requirements.txt..."
	@echo

	@source ./venv/bin/activate && \
	pip install --upgrade pip && \
	set -a && \
	source $(DOCKER_BUILD_ARGUMENTS) && \
	set +a && \
	pip3 install -r app/requirements.txt

local-migrate: ##@ Run migrations
	@echo
	@echo "Running migrations..."
	@echo
	@cd app && \
	source ../venv/bin/activate && \
	python manage.py makemigrations && \
	python manage.py migrate && \
	python manage.py migrate --run-syncdb

local-server: ##@ Start the django server
	@echo
	@echo "Running python server locally..."
	@echo
	@cd app && \
	source ../venv/bin/activate && \
	python manage.py runserver

local-flush: ##@ Reset the entire database
	@echo
	@echo "Flushing database..."
	@echo
	@cd app && \
	source ../venv/bin/activate && \
	python manage.py flush

local-superuser: ##@ Create a superuser
	@echo
	@echo "Creating superuser..."
	@echo
	@cd app && \
	source ../venv/bin/activate && \
	python manage.py createsuperuser

##@
##@ Misc commands
##@

.PHONY: help hookdeck

hookdeck: ##@ Setup a hookdeck tunnel to receive webhooks on localhost
	@echo
	@echo "Setting up a hookdeck tunnel..."
	@echo
	@hookdeck login
	hookdeck listen 8000 Paddle --path /paddle/webhooks/

# Modified from: https://gist.github.com/prwhite/8168133
help: ##@ (Default) Show this help
	@printf "\nUsage (with docker): make <environment> <target>"
	@printf "\nUsage (without docker): make <target>\n"
	@grep -F -h "##@" $(MAKEFILE_LIST) | grep -F -v grep -F | sed -e 's/\\$$//' | awk 'BEGIN {FS = ":*[[:space:]]*##@[[:space:]]*"}; \
	{ \
		if($$2 == "") \
			printf ""; \
		else if($$0 ~ /^#/) \
			printf "\n%s\n\n", $$2; \
		else if($$1 == "") \
			printf "     %-20s%s\n", "", $$2; \
		else \
			printf "    \033[34m%-20s\033[0m %s\n", $$1, $$2; \
	}'
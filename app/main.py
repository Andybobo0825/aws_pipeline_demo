import logging
import os
import sys

from flask import Flask, jsonify, render_template, request


def create_app() -> Flask:
    app = Flask(__name__)

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    app.logger.handlers.clear()
    app.logger.addHandler(handler)
    app.logger.setLevel(logging.INFO)

    @app.before_request
    def log_request() -> None:
        app.logger.info("request path=%s method=%s", request.path, request.method)

    @app.get("/")
    def index():
        return render_template("index.html", app_env=os.getenv("APP_ENV", "unknown"))

    @app.get("/health")
    def health():
        return jsonify({"status": "ok"}), 200

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

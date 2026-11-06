import os
import secrets
from urllib.parse import quote

import requests
from flask import Flask, flash, redirect, render_template, request, url_for

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY") or secrets.token_hex(32)
BACKEND_URL = os.environ.get("BACKEND_URL", "http://127.0.0.1:8000").rstrip("/")


class BackendError(Exception):
    pass


def call_backend(method: str, path: str, **kwargs):
    try:
        response = requests.request(
            method,
            f"{BACKEND_URL}{path}",
            timeout=5,
            **kwargs,
        )
    except requests.RequestException as exc:
        raise BackendError(f"Could not reach backend at {BACKEND_URL}: {exc}") from exc

    if not response.ok:
        try:
            detail = response.json().get("detail", response.text)
        except requests.exceptions.JSONDecodeError:
            detail = response.text
        raise BackendError(f"Backend returned HTTP {response.status_code}: {detail}")

    if response.status_code == 204:
        return None
    return response.json()


def render_home(hello=None):
    try:
        items = call_backend("GET", "/shopping-list")
    except BackendError as exc:
        flash(str(exc), "error")
        items = []
    return render_template("index.html", items=items, hello=hello)


@app.get("/")
def index():
    return render_home()


@app.get("/hello")
def hello():
    try:
        result = call_backend("GET", "/hello")
    except BackendError as exc:
        flash(str(exc), "error")
        result = None
    return render_home(hello=result)


@app.post("/items")
def create_item():
    name = request.form.get("name", "").strip()
    try:
        amount = int(request.form.get("amount", ""))
        if not name or amount < 0:
            raise ValueError
    except ValueError:
        flash("Enter an item name and a non-negative whole-number amount.", "error")
        return redirect(url_for("index"))

    try:
        call_backend("POST", "/shopping-list", json={"name": name, "amount": amount})
    except BackendError as exc:
        flash(str(exc), "error")
    else:
        flash(f"Added {name}.", "success")
    return redirect(url_for("index"))


@app.post("/items/<name>/update")
def update_item(name: str):
    try:
        amount = int(request.form.get("amount", ""))
        if amount < 0:
            raise ValueError
    except ValueError:
        flash("Amount must be a non-negative whole number.", "error")
        return redirect(url_for("index"))

    try:
        call_backend(
            "PUT",
            f"/shopping-list/{quote(name, safe='')}",
            json={"name": name, "amount": amount},
        )
    except BackendError as exc:
        flash(str(exc), "error")
    else:
        flash(f"Updated {name}.", "success")
    return redirect(url_for("index"))


@app.post("/items/<name>/delete")
def delete_item(name: str):
    try:
        call_backend("DELETE", f"/shopping-list/{quote(name, safe='')}")
    except BackendError as exc:
        flash(str(exc), "error")
    else:
        flash(f"Deleted {name}.", "success")
    return redirect(url_for("index"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")))

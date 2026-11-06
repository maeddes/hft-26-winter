import socket

from fastapi import FastAPI, HTTPException, Response, status
from pydantic import BaseModel, Field

app = FastAPI(title="Shopping List API")


class ShoppingItem(BaseModel):
    name: str = Field(min_length=1)
    amount: int = Field(ge=0)


shopping_list: dict[str, ShoppingItem] = {}


@app.get("/hello")
def hello() -> dict[str, str]:
    return {"message": "Good Morning!", "hostname": socket.gethostname()}


@app.get("/crash")
def crash() -> None:
    raise RuntimeError("Simulated application error")


@app.get("/shopping-list", response_model=list[ShoppingItem])
def list_items() -> list[ShoppingItem]:
    return list(shopping_list.values())


@app.post(
    "/shopping-list",
    response_model=ShoppingItem,
    status_code=status.HTTP_201_CREATED,
)
def create_item(item: ShoppingItem) -> ShoppingItem:
    if item.name in shopping_list:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Item already exists")
    shopping_list[item.name] = item
    return item


@app.get("/shopping-list/{name}", response_model=ShoppingItem)
def get_item(name: str) -> ShoppingItem:
    item = shopping_list.get(name)
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return item


@app.put("/shopping-list/{name}", response_model=ShoppingItem)
def update_item(name: str, item: ShoppingItem) -> ShoppingItem:
    if name not in shopping_list:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    if item.name != name:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Item name must match the path",
        )
    shopping_list[name] = item
    return item


@app.delete("/shopping-list/{name}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(name: str) -> Response:
    if name not in shopping_list:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    del shopping_list[name]
    return Response(status_code=status.HTTP_204_NO_CONTENT)

class UserRepository:
    def find_user(self, user_id: str) -> dict[str, str]:
        return {"id": user_id, "name": "Ada"}


class UserService:
    def __init__(self, repository: UserRepository) -> None:
        self.repository = repository

    def get_display_name(self, user_id: str) -> str:
        user = self.repository.find_user(user_id)
        return user["name"]

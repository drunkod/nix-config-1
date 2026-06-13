from service import UserRepository, UserService


def main() -> None:
    service = UserService(UserRepository())
    print(service.get_display_name("42"))


if __name__ == "__main__":
    main()

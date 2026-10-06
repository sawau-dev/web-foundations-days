const loadButton = document.getElementById("load-users");
const filterInput = document.getElementById("filter-input");
const status = document.getElementById("status");
const usersList = document.getElementById("users-list");

let users = [];

function renderUsers(list) {
    usersList.replaceChildren();

    if (list.length === 0) {
        const emptyMessage = document.createElement("li");
        emptyMessage.textContent = "No users match your filter.";
        usersList.appendChild(emptyMessage);
        return;
    }

    list.forEach((user) => {
        const listItem = document.createElement("li");

        const name = document.createElement("h2");
        name.textContent = user.name;

        const email = document.createElement("p");
        email.textContent = `Email: ${user.email}`;

        const city = document.createElement("p");
        city.textContent = `City: ${user.address.city}`;

        const company = document.createElement("p");
        company.textContent = `Company: ${user.company.name}`;

        listItem.appendChild(name);
        listItem.appendChild(email);
        listItem.appendChild(city);
        listItem.appendChild(company);

        usersList.appendChild(listItem);
    });
}

async function loadUsers() {
    loadButton.disabled = true;
    status.textContent = "Loading users...";
    usersList.replaceChildren();

    try {
        const response = await fetch(
            "https://jsonplaceholder.typicode.com/users"
        );

        if (!response.ok) {
            throw new Error(`Request failed with status ${response.status}`);
        }

        users = await response.json();

        renderUsers(users);

        status.textContent = `Successfully loaded ${users.length} users.`;
    } catch (error) {
        users = [];
        usersList.replaceChildren();

        status.textContent =
            "Unable to load users. Please check your connection and try again.";

        console.error("Error loading users:", error);
    } finally {
        loadButton.disabled = false;
    }
}

filterInput.addEventListener("input", () => {
    const searchText = filterInput.value.trim().toLowerCase();

    const filteredUsers = users.filter((user) =>
        user.name.toLowerCase().includes(searchText)
    );

    renderUsers(filteredUsers);

    if (searchText && filteredUsers.length === 0) {
        status.textContent = "No users match your filter.";
    } else if (searchText) {
        status.textContent = `${filteredUsers.length} user(s) match your filter.`;
    } else if (users.length > 0) {
        status.textContent = `Showing all ${users.length} users.`;
    }
});

loadButton.addEventListener("click", loadUsers);

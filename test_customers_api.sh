#!/bin/bash

BASE_URL="http://localhost:8080/api/customers"
CONTENT_TYPE="Content-Type: application/json"
ACCEPT="Accept: application/json"

echo "===================="
echo "1) GET All Customers"
echo "===================="
curl -s -X GET "$BASE_URL" -H "$ACCEPT" | jq .
echo

echo "===================="
echo "2) POST Create Customer"
echo "===================="
CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL" \
  -H "$CONTENT_TYPE" \
  -H "$ACCEPT" \
  -d '{
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com"
  }')
echo "$CREATE_RESPONSE" | jq .

# ดึง ID จาก response
NEW_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
echo "Created Customer ID: $NEW_ID"
echo

echo "===================="
echo "3) GET Customer by ID"
echo "===================="
curl -s -X GET "$BASE_URL/$NEW_ID" -H "$ACCEPT" | jq .
echo

echo "===================="
echo "4) PUT Update Customer"
echo "===================="
curl -s -X PUT "$BASE_URL/$NEW_ID" \
  -H "$CONTENT_TYPE" \
  -H "$ACCEPT" \
  -d '{
    "firstName": "Johnny",
    "lastName": "Doe",
    "email": "johnny.doe@example.com"
  }' | jq .
echo

echo "===================="
echo "5) DELETE Customer"
echo "===================="
curl -s -X DELETE "$BASE_URL/$NEW_ID" -w "\nHTTP Status: %{http_code}\n"
echo

echo "===================="
echo "6) GET All Customers (After Delete)"
echo "===================="
curl -s -X GET "$BASE_URL" -H "$ACCEPT" | jq .
echo

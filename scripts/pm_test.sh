#!/bin/bash
dfx stop
dfx start --background --clean

dfx identity list | grep -q "^000Admin$" || dfx identity new 000Admin
export Admin=$(dfx identity get-principal --identity 000Admin)
dfx identity use 000Admin

dfx deploy pm

dfx identity list | grep -q "^0000TestUser1$" || dfx identity new 0000TestUser1
export TestUser1=$(dfx identity get-principal --identity 0000TestUser1)

dfx identity list | grep -q "^0000TestUser2$" || dfx identity new 0000TestUser2
export TestUser2=$(dfx identity get-principal --identity 0000TestUser2)

dfx identity list | grep -q "^0000TestUser3$" || dfx identity new 0000TestUser3
export TestUser3=$(dfx identity get-principal --identity 0000TestUser3)

dfx identity list | grep -q "^0000TestUser4$" || dfx identity new 0000TestUser4
export TestUser4=$(dfx identity get-principal --identity 0000TestUser4)

dfx identity list | grep -q "^0000TestUser5$" || dfx identity new 0000TestUser5
export TestUser5=$(dfx identity get-principal --identity 0000TestUser5)

echo "Creando usuarios...\n"

dfx identity use 0000TestUser1
dfx canister call pm signUp '("Usuario Uno")'

dfx identity use 0000TestUser2
dfx canister call pm signUp '("Usuario Dos")'

dfx identity use 0000TestUser3
dfx canister call pm signUp '("Usuario Tres")'

dfx identity use 0000TestUser4
dfx canister call pm signUp '("Usuario Cuatro")'

dfx identity use 0000TestUser5
dfx canister call pm signUp '("Usuario Cinco")'

echo "Usuario Uno crea Workspace...\n"

dfx identity use 0000TestUser1
dfx canister call pm createWorkspace '(
  record {
    name = "Worspace Usuario Uno";
    description = "Descripcion del workspace del usuario uno";
  },
)'
WORKSPACE_ID=$(dfx canister call pm getMyWorkspaces | grep -o '[0-9_]\+' | tr -d '_')

dfx canister call pm editWorkspace "(
  record {
    logo = null;
    name = null;
    description = null;
    coverImage = null;
    details = opt \"Detalles del workspace Uno\";
  },
  $WORKSPACE_ID: int,
)"




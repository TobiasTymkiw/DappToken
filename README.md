# DappToken - Proyecto final del Módulo 5 de ETH-Kipu

 Para poder correr el proyecto localmente asegurate de tener declarada con  *npx hardhat vars set "nombre de las variables"* la siguiente variable: 

 - DAPP_TOKEN_OWNER

### Pasos para compilar el proyecto:

1. En la terminal: npm install --save-dev hardhat
2. En la terminal: npx hardhat compile
3. En la terminal: npx hardhat ignition deploy ignition/modules/TokenFarmModule.ts --network localhost

### Tests con los que cuenta el proyecto:

- Mintea LP Tokens al firstUser.
- Deposita LP Tokens al contrato TokenFarm.
- Distribuye recompensas todos los Stakers y emite un evento.
- Permite reclamar recompensas a los Stakers y transfiere a sus cuentas.
- Permite retirar LP Tokens a los Stakers  y reclamar Dapp Tokens Rewards.
- Permite al Owner actualizar la recompensa del bloque dentro de un rango.
- Debe revertir si la recompensa se quiere setear por debajo del minimo.
- Debe revertir si la recompensa se quiere setear por encima del maximo.

#### Correr los tests con: 
- npx hardhat test ./test/TokenFarm.test.ts
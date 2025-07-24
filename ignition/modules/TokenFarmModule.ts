import { buildModule } from "@nomicfoundation/ignition-core";
import { vars } from "hardhat/config";

const contractOwner = vars.get("DAPP_TOKEN_OWNER");

export default buildModule("TokenFarmModule", (m) => {
  // Deploy DappToken and LPToken
  const dappToken = m.contract("DappToken" , [contractOwner]);
  const lpToken = m.contract("LPToken", [contractOwner]);
  // Deploy TokenFarm with the addresses of DappToken and LPToken
  const tokenFarm = m.contract("TokenFarm", [dappToken, lpToken]);

  return { dappToken, lpToken, tokenFarm };
});

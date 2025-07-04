import { buildModule } from "@nomicfoundation/ignition-core";

export default buildModule("TokenFarmModule", (m) => {
  // Deploy DappToken and LPToken first with an owner address
    const dappToken = m.contract("DappToken", [
        "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // Owner address
    ]);
    const lpToken = m.contract("LPToken", [
        "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // Owner address
    ]);

  // Deploy TokenFarm with the addresses of DappToken and LPToken
  // set the msg sender
  const tokenFarm = m.contract("TokenFarm", [dappToken, lpToken], {
    from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  });
  //const tokenFarm = m.contract("TokenFarm", [dappToken, lpToken]);

  return { dappToken, lpToken, tokenFarm };
});

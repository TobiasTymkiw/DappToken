import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("TokenFarm", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployDappTokenFarmFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, secondAccount, thirdAccount] = await hre.ethers.getSigners();

    const TokenFarm = await hre.ethers.getContractFactory("TokenFarm");
    const LPToken = await hre.ethers.getContractFactory("LPToken");
    const DappToken = await hre.ethers.getContractFactory("DappToken");

    // Deploy the LPToken and DappToken contracts with the owner address

    // Deploy the TokenFarm contract with the addresses of DappToken and LPToken

    const lpToken = await LPToken.deploy(owner.address);
    const dappToken = await DappToken.deploy(owner.address);
    const tokenFarm = await TokenFarm.deploy(
      dappToken.getAddress(),
      lpToken.getAddress()
    );
    await dappToken.transferOwnership(tokenFarm.getAddress());

    return {
      tokenFarm,
      lpToken,
      dappToken,
      owner,
      secondAccount,
      thirdAccount,
    };
  }
  //Mint LPT from LPToken contract the second account.
  it("Should mint LP tokens to the second account", async function () {
    const { lpToken, secondAccount } = await loadFixture(
      deployDappTokenFarmFixture
    );

    // Mint LP tokens to the second account
    const mintAmount = hre.ethers.parseEther("100");
    await lpToken.mint(secondAccount.address, mintAmount);

    // Check the balance of the second account
    const balance = await lpToken.balanceOf(secondAccount.address);
    //show on console the balance
    //console.log(`LP Token balance of second account: ${ethers.formatEther(balance)}`);
    //expect the balance to be equal to the mint amount
    expect(balance).to.equal(mintAmount);
  });
  //Deposit LP tokens into the TokenFarm contract.
  it("Should deposit LP tokens into the TokenFarm contract", async function () {
    const { tokenFarm, lpToken, secondAccount } = await loadFixture(
      deployDappTokenFarmFixture
    );

    // Mint LP tokens to the second account.
    const mintAmount = hre.ethers.parseEther("100");
    await lpToken.mint(secondAccount.address, mintAmount);

    // Approve the TokenFarm contract to spend LP tokens on behalf of the second account.
    await lpToken.connect(secondAccount).approve(tokenFarm, mintAmount);

    // Excpect an event called "Deposit" to be emitted.
    await expect(tokenFarm.connect(secondAccount).deposit(mintAmount))
      .to.emit(tokenFarm, "Deposit")
      .withArgs(secondAccount.address, mintAmount);
  });
  //Distribute rewards to all stakers.
  it("Should distribute rewards to all stakers and emit an event", async function () {
    const { tokenFarm, lpToken, secondAccount, thirdAccount } =
      await loadFixture(deployDappTokenFarmFixture);

    // Mint LP tokens to the second account.
    const mintAmount = hre.ethers.parseEther("1000");
    const spendAmount = hre.ethers.parseEther("100");
    await lpToken.mint(secondAccount.address, mintAmount);
    await lpToken.mint(thirdAccount.address, mintAmount);

    // Approve the TokenFarm contract to spend LP tokens on behalf of the second account.
    await lpToken.connect(secondAccount).approve(tokenFarm, mintAmount);
    await lpToken.connect(thirdAccount).approve(tokenFarm, mintAmount);

    // Deposit LP tokens into the TokenFarm contract.
    await tokenFarm.connect(secondAccount).deposit(spendAmount);
    await tokenFarm.connect(secondAccount).deposit(spendAmount);
    await tokenFarm.connect(secondAccount).deposit(spendAmount);
    await tokenFarm.connect(secondAccount).deposit(spendAmount);
    await tokenFarm.connect(thirdAccount).deposit(spendAmount);
    await tokenFarm.connect(thirdAccount).deposit(spendAmount);

    // Advance the block number to simulate time passing.10 blocks.
    await time.increase(10 * 15); // Assuming 15 seconds per block

    // Distribute rewards to all stakers.
    await expect(tokenFarm.distributeRewardsAll())
      .to.emit(tokenFarm, "RewardsDistributed")
      .withArgs("Rewards distributed to all stakers");
  });
  //Stakers can claim their rewards.
  it("Should allow stakers to claim their rewards and successfully transfered to his account", async function () {
    const { tokenFarm, lpToken, dappToken, secondAccount, thirdAccount } =
      await loadFixture(deployDappTokenFarmFixture);

    // Mint LP tokens to the second account.
    const mintAmount = hre.ethers.parseEther("1000");
    const spendAmount = hre.ethers.parseEther("100");
    await lpToken.mint(secondAccount.address, mintAmount);
    await lpToken.mint(thirdAccount.address, mintAmount);

    // Approve the TokenFarm contract to spend LP tokens on behalf of the second account.
    await lpToken.connect(secondAccount).approve(tokenFarm, mintAmount);
    await lpToken.connect(thirdAccount).approve(tokenFarm, mintAmount);

    // Deposit LP tokens into the TokenFarm contract.
    await tokenFarm.connect(secondAccount).deposit(spendAmount);
    await tokenFarm.connect(thirdAccount).deposit(spendAmount);

    // Advance the block number to simulate time passing.30 blocks.
    for (let i = 0; i < 30; i++) {
      await hre.network.provider.send("evm_increaseTime", [15]);
      await hre.network.provider.send("evm_mine");
    }
    //distribute rewards to all stakers.
    await tokenFarm.distributeRewardsAll();
    // Claim rewards for the second account.
    const stakerInfo = await tokenFarm.stakersInfo(secondAccount.address);
    await expect(tokenFarm.connect(secondAccount).claimRewards())
      .to.emit(tokenFarm, "RewardsClaimed")
      .withArgs(
        secondAccount.address,
        stakerInfo[2] // The amount of Rewards claimed
      );
  });
  //Stakers can withdraw their LP tokens from the TokenFarm contract and claim rewards.
  it("Should allow stakers to withdraw their LP tokens and claim rewards", async function () {
    const { tokenFarm, lpToken, secondAccount, thirdAccount } =
      await loadFixture(deployDappTokenFarmFixture);

    // Mint LP tokens to the second account.
    const mintAmount = hre.ethers.parseEther("1000");
    const spendAmount = hre.ethers.parseEther("100");
    await lpToken.mint(secondAccount.address, mintAmount);
    await lpToken.mint(thirdAccount.address, mintAmount);

    // Approve the TokenFarm contract to spend LP tokens on behalf of the second account.
    await lpToken.connect(secondAccount).approve(tokenFarm, mintAmount);
    await lpToken.connect(thirdAccount).approve(tokenFarm, mintAmount);

    // Deposit LP tokens into the TokenFarm contract.
    await tokenFarm.connect(secondAccount).deposit(spendAmount);
    await tokenFarm.connect(thirdAccount).deposit(spendAmount);

    // Advance the block number to simulate time passing.30 blocks.
    for (let i = 0; i < 30; i++) {
      await hre.network.provider.send("evm_increaseTime", [15]);
      await hre.network.provider.send("evm_mine");
    }

    // Distribute rewards to all stakers.
    await tokenFarm.distributeRewardsAll();

    // Check the balance of the second account Before withdrawing
    const stakerInfo = await tokenFarm.stakersInfo(secondAccount.address);
    //console.log(`User balance before withdraw: ${stakerInfo[0]}`);

    // Withdraw LP tokens from the TokenFarm contract.
    await expect(tokenFarm.connect(secondAccount).withdraw())
      .to.emit(tokenFarm, "Withdraw")
      .withArgs(secondAccount.address, stakerInfo[0]);
    //Claim rewards after withdrawing.
    await expect(tokenFarm.connect(secondAccount).claimRewards())
      .to.emit(tokenFarm, "RewardsClaimed")
      .withArgs(
        secondAccount.address,
        stakerInfo[2] // The amount of DappTokens claimed
      );
  });

  it("should allow owner to update rewardPerBlock within range", async () => {
  const { tokenFarm, owner } = await loadFixture(deployDappTokenFarmFixture);

  const newReward = ethers.parseEther("2"); // 2 tokens por bloque
  await tokenFarm.connect(owner).setRewardPerBlock(newReward);

  expect(await tokenFarm.REWARD_PER_BLOCK()).to.equal(newReward);
});

it("should revert if rewardPerBlock is set below minimum", async () => {
  const { tokenFarm, owner } = await loadFixture(deployDappTokenFarmFixture);

  const tooLow = ethers.parseEther("0.05");
  await expect(tokenFarm.connect(owner).setRewardPerBlock(tooLow)).to.be.revertedWith("Below minimum reward");
});

});

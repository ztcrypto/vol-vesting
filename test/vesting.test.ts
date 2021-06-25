import "@nomiclabs/hardhat-ethers";
import { ethers } from "hardhat";
import { Signer, BigNumber } from "ethers";
import chai, { expect } from "chai";
import { TestToken } from "../typechain/TestToken";
import { LinearVestingVault } from "../typechain/LinearVestingVault";
import { increaseTime, lastBlock } from "./utils";
import { solidity } from "ethereum-waffle"

chai.use(solidity)

const BN = BigNumber.from;

describe("Test Token Vesting", function () {
  let owner: Signer, account1: Signer;

  const decimals: BigNumber = BN(10).pow(BN(18));

  let token: TestToken;
  let tokenVesting: LinearVestingVault;

  beforeEach(async () => {
    [owner, account1] = await ethers.getSigners();
    const tokenFactory = await ethers.getContractFactory("TestToken");
    token = (await tokenFactory.deploy()) as TestToken;

    const tokenVestingFact = await ethers.getContractFactory("LinearVestingVault");
    tokenVesting = (await tokenVestingFact.deploy(
      token.address
    )) as LinearVestingVault;
  });
  
  it("Test Token Deployment", async () => {
    expect(await token.name()).to.equal("Test Token");
    expect(await token.symbol()).to.equal("TEST");
    expect(await token.balanceOf(await owner.getAddress())).equal(
      BN(1000000).mul(decimals)
    );
  });

  it("release by index once should work", async () => {
    const vestAmount = BN(30).mul(decimals);
    const vestAdd = await account1.getAddress();
    await token.approve(tokenVesting.address, vestAmount);
    const block: any = await lastBlock();   
    await tokenVesting.issue(vestAdd, vestAmount, 
      parseInt(block.timestamp) + 2, 0, 10, 0);
    await increaseTime(10);
    expect(await token.balanceOf(vestAdd)).to.equal(0);
    await tokenVesting.release(vestAdd, 0);
    expect(await token.balanceOf(vestAdd)).to.equal(vestAmount);
  });

  it("release by index twice should work", async () => {
    const vestAmount = BN(30).mul(decimals);
    const vestAdd = await account1.getAddress();
    await token.approve(tokenVesting.address, vestAmount.mul(2));
    const block: any = await lastBlock();   
    await tokenVesting.issue(vestAdd, vestAmount, 
      parseInt(block.timestamp) + 2, 0, 10, 0);
    await tokenVesting.issue(vestAdd, vestAmount, 
      parseInt(block.timestamp) + 12, 0, 10, 0);
    await increaseTime(20);
    expect(await token.balanceOf(vestAdd)).to.equal(0);
    await tokenVesting.release(vestAdd, 0);
    await tokenVesting.release(vestAdd, 1);
    expect(await token.balanceOf(vestAdd)).to.equal(vestAmount.mul(2));
  });

  it("releaseAll should work", async () => {
    const vestAmount = BN(30).mul(decimals);
    const vestAdd = await account1.getAddress();
    await token.approve(tokenVesting.address, vestAmount.mul(2));
    const block: any = await lastBlock();   
    await tokenVesting.issue(vestAdd, vestAmount, 
      parseInt(block.timestamp) + 2, 0, 10, 0);
    await tokenVesting.issue(vestAdd, vestAmount, 
      parseInt(block.timestamp) + 12, 0, 10, 0);
    await increaseTime(20);
    expect(await token.balanceOf(vestAdd)).to.equal(0);
    await tokenVesting.releaseAll(vestAdd);
    expect(await token.balanceOf(vestAdd)).to.equal(vestAmount.mul(2));
  });

  it("rovoke by index should work", async () => {
    const vestAmount = BN(30).mul(decimals);
    const vestAdd = await account1.getAddress();
    await token.approve(tokenVesting.address, vestAmount.mul(2));
    const block: any = await lastBlock();   
    await tokenVesting.issue(vestAdd, vestAmount, 
      parseInt(block.timestamp) + 2, 0, 10, 0);
    await tokenVesting.issue(vestAdd, vestAmount, 
      parseInt(block.timestamp) + 12, 0, 10, 0);
    await tokenVesting.revoke(vestAdd, 0);
    await increaseTime(20);
    expect(await token.balanceOf(vestAdd)).to.equal(0);
    await tokenVesting.releaseAll(vestAdd);
    expect(await token.balanceOf(vestAdd)).to.equal(vestAmount);
  });
});

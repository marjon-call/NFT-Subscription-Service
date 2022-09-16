const { expect } = require("chai");
const diamond = require('diamond-util')
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");


async function mineNBlocks(n) {
  for (let index = 0; index < n; index++) {
    await ethers.provider.send('evm_mine');
  }
}


describe("Deploy Diamond", function () {

  async function deployDiamondFixture() {

    const [owner, addy1, addy2] = await ethers.getSigners()

    
    // eslint-disable-next-line no-unused-vars
    const deployedDiamond = await diamond.deploy({
      diamondName: 'LeaseDiamond',
      facets: [
        'DiamondCutFacet',
        'DiamondLoupeFacet',
        'LeaseERC721Facet',
        'SubscriptionManager'
      ],
      args: [owner.address, "Lease Token", "RENT", ethers.utils.parseEther("0.1"), 10]
    })


    // init facets
    const diamondCutFacet = await ethers.getContractAt('DiamondCutFacet', deployedDiamond.address)
    const diamondLoupeFacet = await ethers.getContractAt('DiamondLoupeFacet', deployedDiamond.address)
    const leaseFacet = await ethers.getContractAt('LeaseERC721Facet', deployedDiamond.address)
    const subFacet = await ethers.getContractAt('SubscriptionManager', deployedDiamond.address)


    // deploy club token
    const ClubToken = await ethers.getContractFactory("ClubToken");
    const clubToken = await ClubToken.deploy();

    // make diamond owner of club token
    await clubToken.transferOwnership(deployedDiamond.address)

    // set up subFacet
    await subFacet.setClubToken(clubToken.address)
    await subFacet.setRewardAmount(10)
    await subFacet.setTokenConversionRation(100)
    await subFacet.setBlocksBetweenUpdate(1)
    


  
    return { deployedDiamond, diamondCutFacet, diamondLoupeFacet, leaseFacet, subFacet, clubToken, owner, addy1, addy2 }
  }


  it("Deploy Diamond Sucessfully", async function () {
    const { deployedDiamond, diamondCutFacet, diamondLoupeFacet, leaseFacet, subFacet, clubToken, owner, addy1, addy2 } = await loadFixture(deployDiamondFixture);
    expect(deployedDiamond.address).to.not.equal("0x0")

    const name = await leaseFacet.name()
    const symbol = await leaseFacet.symbol()

    expect(name).to.equal("Lease Token")
    expect(symbol).to.equal("RENT")
  });

  it("LEASE FACET: should mint", async function () {
    const { deployedDiamond, diamondCutFacet, diamondLoupeFacet, leaseFacet, subFacet, clubToken, owner, addy1, addy2 } = await loadFixture(deployDiamondFixture);

    await leaseFacet.connect(addy1).mint(addy1.address, {value: ethers.utils.parseEther("1")})

    const ownerOf1 = await leaseFacet.ownerOf(1)

    expect(ownerOf1).to.equal(addy1.address)

  })

  it("LEASE FACET: should reclaim", async function () {
    const { deployedDiamond, diamondCutFacet, diamondLoupeFacet, leaseFacet,  subFacet, clubToken, owner, addy1, addy2 } = await loadFixture(deployDiamondFixture);

    await leaseFacet.connect(addy1).mint(addy1.address, {value: ethers.utils.parseEther("1")})

    let rentRemaining = await leaseFacet.getRentedBlocksRemaining(1)
    // console.log(rentRemaining)
    expect(rentRemaining).to.equal(100)


    await mineNBlocks(90)

    rentRemaining = await leaseFacet.getRentedBlocksRemaining(1)
    // console.log(rentRemaining)
    expect(rentRemaining).to.equal(10)


    await mineNBlocks(10) 


    rentRemaining = await leaseFacet.getRentedBlocksRemaining(1)
    // console.log(rentRemaining)
    expect(rentRemaining).to.equal(0)

    await leaseFacet.reclaim(1)

    const ownerOf1 = await leaseFacet.ownerOf(1)
    expect(ownerOf1).to.equal(deployedDiamond.address)

    expect(await leaseFacet.balanceOf(addy1.address)).to.equal(0)

  })


  it("LEASE FACET: should batch reclaim", async function () {
    const { deployedDiamond, diamondCutFacet, diamondLoupeFacet, leaseFacet, subFacet, clubToken, owner, addy1, addy2 } = await loadFixture(deployDiamondFixture);

    await leaseFacet.connect(addy1).mint(addy1.address, {value: ethers.utils.parseEther("1")})
    await leaseFacet.connect(addy2).mint(addy2.address, {value: ethers.utils.parseEther("1")})

    
    await mineNBlocks(100)    
   

    await leaseFacet.reclaimBatch([1,2])


    const ownerOf1 = await leaseFacet.ownerOf(1)
    expect(ownerOf1).to.equal(deployedDiamond.address)
    expect(await leaseFacet.balanceOf(addy1.address)).to.equal(0)

    const ownerOf2 = await leaseFacet.ownerOf(2)
    expect(ownerOf2).to.equal(deployedDiamond.address)
    expect(await leaseFacet.balanceOf(addy2.address)).to.equal(0)

  })


  it("LEASE FACET: should repurchase", async function () {
    const { deployedDiamond, diamondCutFacet, diamondLoupeFacet, leaseFacet, subFacet, clubToken, owner, addy1, addy2 } = await loadFixture(deployDiamondFixture);

    await leaseFacet.connect(addy1).mint(addy1.address, {value: ethers.utils.parseEther("1")})
    
    await mineNBlocks(100)    
   
    await leaseFacet.reclaim(1)

    let ownerOf1 = await leaseFacet.ownerOf(1)
    expect(ownerOf1).to.equal(deployedDiamond.address)
    expect(await leaseFacet.balanceOf(addy1.address)).to.equal(0)

    await leaseFacet.connect(addy1).repurchase(1, {value: ethers.utils.parseEther("1")})

    ownerOf1 = await leaseFacet.ownerOf(1)
    expect(ownerOf1).to.equal(addy1.address)
    expect(await leaseFacet.balanceOf(deployedDiamond.address)).to.equal(0)

  })


  it("LEASE FACET: should not allow repurchase by wrong user", async function () {
    const { deployedDiamond, diamondCutFacet, diamondLoupeFacet, leaseFacet, subFacet, clubToken, owner, addy1, addy2 } = await loadFixture(deployDiamondFixture);

    await leaseFacet.connect(addy1).mint(addy1.address, {value: ethers.utils.parseEther("1")})
    
    await mineNBlocks(100)    
   
    await leaseFacet.reclaim(1)

    let ownerOf1 = await leaseFacet.ownerOf(1)
    expect(ownerOf1).to.equal(deployedDiamond.address)
    expect(await leaseFacet.balanceOf(addy1.address)).to.equal(0)

    try {
      await leaseFacet.connect(addy2).repurchase(1, {value: ethers.utils.parseEther("1")})
    } catch(e) {
      expect(e.message.includes("LeaseERC721Factet: user was not the previous owner of token")).to.equal(true)
    }
    

    ownerOf1 = await leaseFacet.ownerOf(1)
    expect(ownerOf1).to.equal(deployedDiamond.address)
    expect(await leaseFacet.balanceOf(addy2.address)).to.equal(0)

  })


  it("LEASE FACET: should pay rent", async function () {
    const { deployedDiamond, diamondCutFacet, diamondLoupeFacet, leaseFacet, subFacet, clubToken, owner, addy1, addy2 } = await loadFixture(deployDiamondFixture);

    await leaseFacet.connect(addy1).mint(addy1.address, {value: ethers.utils.parseEther("1")})
    
    await mineNBlocks(100)    
   
    let rentRemaining = await leaseFacet.getRentedBlocksRemaining(1)
    expect(rentRemaining).to.equal(0)

    await leaseFacet.connect(addy1).payRent(1, {value: ethers.utils.parseEther("0.1")})

    rentRemaining = await leaseFacet.getRentedBlocksRemaining(1)
    expect(rentRemaining).to.equal(10)

  })


  it("SUB FACET: update user status", async function () {
    const { deployedDiamond, diamondCutFacet, diamondLoupeFacet, leaseFacet, subFacet, clubToken, owner, addy1, addy2 } = await loadFixture(deployDiamondFixture);

    await leaseFacet.connect(addy1).mint(addy1.address, {value: ethers.utils.parseEther("2")})
    await leaseFacet.connect(addy2).mint(addy2.address, {value: ethers.utils.parseEther("1")})

    await mineNBlocks(100)

    await subFacet.updateUsersStatus()


    let ownerOf1 = await leaseFacet.ownerOf(1)
    expect(ownerOf1).to.equal(addy1.address)
    expect(await leaseFacet.balanceOf(addy1.address)).to.equal(1)

    
   
    let ownerOf2 = await leaseFacet.ownerOf(2)
    expect(ownerOf2).to.equal(deployedDiamond.address)
    expect(await leaseFacet.balanceOf(addy2.address)).to.equal(0)


    let addy1CTBal = await clubToken.balanceOf(addy1.address)

    expect(addy1CTBal).to.equal(10)

  })


  

  it("SUB FACET: redeem rent with club token", async function () {
    const { deployedDiamond, diamondCutFacet, diamondLoupeFacet, leaseFacet, subFacet, clubToken, owner, addy1, addy2 } = await loadFixture(deployDiamondFixture);

    await leaseFacet.connect(addy1).mint(addy1.address, {value: ethers.utils.parseEther("5")})
    
    for (let i = 0; i < 10; i++) {
      await mineNBlocks(1)
      await subFacet.updateUsersStatus()
    }

    let preRent = await leaseFacet.getRentedBlocksRemaining(1)
    
    await clubToken.connect(addy1).approve(subFacet.address, 100)
    await subFacet.connect(addy1).redeemRentWithRewards(100, 1)

    let postRent = await leaseFacet.getRentedBlocksRemaining(1)

    console.log(preRent)
    console.log(postRent)

    expect(postRent).to.equal(parseInt(preRent) + 8)


    let addy1CTBal = await clubToken.balanceOf(addy1.address)

    console.log(addy1CTBal)

    expect(addy1CTBal).to.equal(0)

  })


  // test require for update status

});

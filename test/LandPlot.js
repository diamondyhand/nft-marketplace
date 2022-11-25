const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");

describe("LandPlot contract", function () {
  let deployedLandPlot;
  let owner, account1, account2;
  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
  const xs = [],
    zs = [];
  for (let index = 0; index < 200; index++) {
    xs.push(index);
    zs.push(index);
  }

  beforeEach(async () => {
    [owner, account1, account2] = await ethers.getSigners();
    const landPlot = await ethers.getContractFactory("LandPlot");
    deployedLandPlot = await upgrades.deployProxy(landPlot, [
      "LandPlot",
      "LPT",
    ]);
    await deployedLandPlot.deployed();
  });

  describe("claimLands", () => {
    it("revert if claiming disabled", async () => {
      await expect(
        deployedLandPlot.connect(account1).claimLands([2, 1], [2, 1], {
          value: 100,
        })
      ).to.be.revertedWith("LandPlot: claiming disabled");
    });

    it("revert if xs and zs array length are greater than 128", async () => {
      await deployedLandPlot.admin_set_claim_status(true);
      await expect(
        deployedLandPlot.connect(account1).claimLands(xs, zs, {
          value: 100,
        })
      ).to.be.revertedWith("LandPlot: invalid param");
    });

    it("revert if xs and zs array length are greater than 128", async () => {
      await deployedLandPlot.admin_set_claim_status(true);
      await expect(
        deployedLandPlot.connect(account1).claimLands([1, 2], [2], {
          value: 100,
        })
      ).to.be.revertedWith("LandPlot: invalid param");
    });

    it("check the land is correctly claimed for free", async () => {
      await deployedLandPlot.admin_set_claim_status(true);
      await deployedLandPlot.connect(account1).claimLands([1, 2], [2, 3], {
        value: 0,
      });
      expect(await deployedLandPlot.connect(account1)._owned(1, 2)).to.equal(2);
      expect(await deployedLandPlot.connect(account1)._owned(2, 3)).to.equal(3);
    });

    it("revert if these is not enough ether when claim lands", async () => {
      await deployedLandPlot.admin_set_claim_status(true);
      await deployedLandPlot.admin_set_plot_costs([1000, 500], [1, 2]);
      await expect(
        deployedLandPlot.connect(account1).claimLands([2, 3], [2, 3], {
          value: 100,
        })
      ).to.be.revertedWith("LandPlot: not enough eth");
    });

    it("revert if coordinate is invalid when claim lands", async () => {
      await deployedLandPlot.admin_set_claim_status(true);
      await deployedLandPlot.admin_set_chunk_limit(200);
      await expect(
        deployedLandPlot.connect(account1).claimLands([2, 3], [2, 3000], {
          value: 10000,
        })
      ).to.be.revertedWith("LandPlot: invalid coordinate");
    });

    it("revert if the land is already minted", async () => {
      await deployedLandPlot.admin_set_claim_status(true);
      await expect(
        deployedLandPlot.connect(account1).claimLands([0], [0], {
          value: 10000,
        })
      ).to.be.revertedWith("LandPlot: already minted");
    });

    it("check the land is correctly claimed with some wei", async () => {
      await deployedLandPlot.admin_set_claim_status(true);
      const balanceBeforeClaim = await account1.getBalance();
      await deployedLandPlot.connect(account1).claimLands([2, 3], [2, 3], {
        value: ethers.utils.parseEther("10"),
      });
      // The balance before claim and after claim are same because _plotPrices and _plotPriceDistances are empty
      expect(await account1.getBalance()).to.equal(balanceBeforeClaim);
      expect(await deployedLandPlot.connect(account1)._owned(2, 2)).to.equal(2);
      expect(await deployedLandPlot.connect(account1)._owned(3, 3)).to.equal(3);
    });
  });

  describe("admin_set_plot_costs test", () => {
    it("revert if prices and distances length are not equal", async () => {
      await expect(
        deployedLandPlot.admin_set_plot_costs([1000, 100], [1])
      ).to.be.revertedWith(
        "LandPlot: prices length and distances should be same"
      );
    });

    it("check admin_set_plot_costs function", async () => {
      await deployedLandPlot.admin_set_plot_costs([1000], [1]);
      expect(await deployedLandPlot._plotPrices(0)).to.equal(1000);
      expect(await deployedLandPlot._plotPriceDistances(0)).to.equal(1);
    });
  });

  describe("admin_set_chunk_limit test", () => {
    it("revert if chunk limit param is invalid when admin sets chunk limit", async () => {
      await expect(
        deployedLandPlot.admin_set_chunk_limit(0)
      ).to.be.revertedWith("LandPlot: invalid chunk limit");
    });

    it("check admin_set_chunk_limit function", async () => {
      await deployedLandPlot.admin_set_chunk_limit(100);
      expect(await deployedLandPlot._chunkLimit()).to.equal(100);
    });
  });

  describe("mintMany test", () => {
    it("revert if xs and zs array length are not equal when admin mints the land", async () => {
      await expect(
        deployedLandPlot.mintMany(account1.getAddress(), [1, 2], [2])
      ).to.be.revertedWith("LandPlot: invalid param");
    });

    it("check the land is correctly minted", async () => {
      await deployedLandPlot.mintMany(account1.getAddress(), [1, 2], [1, 2]);
      expect(await deployedLandPlot.connect(account1)._owned(1, 1)).to.equal(2);
      expect(await deployedLandPlot.connect(account1)._owned(2, 2)).to.equal(3);
    });
  });

  describe("getTokenInfo test", () => {
    beforeEach(async () => {
      await deployedLandPlot.mintMany(account1.getAddress(), [1, 2], [1, 2]);
    });

    it("check get token info function", async () => {
      const tokenInfo3 = await deployedLandPlot.getTokenInfo(3);
      const tokenInfo4 = await deployedLandPlot.getTokenInfo(4);
      expect(tokenInfo3[0]).to.equal(2);
      expect(tokenInfo3[1]).to.equal(2);
      expect(tokenInfo4[0]).to.equal(0);
      expect(tokenInfo4[1]).to.equal(0);
    });

    it("revert if tokenId is less than 1", async () => {
      await expect(deployedLandPlot.getTokenInfo(0)).to.be.revertedWith(
        "LandPlot: invalid tokenId"
      );
    });
  });

  describe("getTokenIdByChunk test", () => {
    it("revert if x,z coordinates are 0 when get token id by chunk", async () => {
      await expect(deployedLandPlot.getTokenIdByChunk(0, 0)).to.be.revertedWith(
        "LandPlot: cann't get token id of chunk [0, 0]"
      );
    });

    it("check get tokenid by chunk", async () => {
      await deployedLandPlot.mintMany(account1.getAddress(), [1, 2], [1, 2]);
      expect(await deployedLandPlot.getTokenIdByChunk(1, 1)).to.equal(2);
    });
  });

  describe("multitransfer test", () => {
    it("revert if transfers NFT to zero address", async () => {
      await expect(
        deployedLandPlot.multitransfer(ZERO_ADDRESS, [])
      ).to.be.revertedWith("LandPlot: invalid address");
    });

    it("revert if tokenids are invalid", async () => {
      await expect(
        deployedLandPlot.multitransfer(account1.getAddress(), [])
      ).to.be.revertedWith("LandPlot: invalid tokenIds");
      await deployedLandPlot.mintMany(account1.getAddress(), [1, 2], [1, 2]);
      await expect(
        deployedLandPlot
          .connect(account1)
          .multitransfer(account2.getAddress(), [2, 4])
      ).to.be.revertedWith("LandPlot: invalid tokenId");
    });

    it("check multitransfer", async () => {
      await deployedLandPlot.mintMany(account1.getAddress(), [1, 2], [1, 2]);
      await deployedLandPlot
        .connect(account1)
        .multitransfer(account2.getAddress(), [2, 3]);
      expect(await deployedLandPlot.ownerOf(2)).to.equal(
        await account2.getAddress()
      );
      expect(await deployedLandPlot.ownerOf(3)).to.equal(
        await account2.getAddress()
      );
    });
  });
});

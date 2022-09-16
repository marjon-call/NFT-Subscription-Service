# NFT-Subscription-Service

TL;DR
A format for a NFT that you can use as proof of subscription. This implementation uses the Diamond Standard.

Using the Diamond Standard, to allow future contract upgrades, I created a subscription based protocol that uses a NFT as record of subscription. The NFT (```LeaseERC721Facet.sol```) is based off of OpenZepplin's ERC721 contract, but adapeted to the Diamond Standard. ```LeaseERC721Facet.sol``` also adds the following functions that taylors its uitlity to a subscription model:

```setRentPrice(uint256 _price) external``` : Updates the cost of rent for one rent period.
```setBaseRentTime(uint256 _blocks) external``` : Updates the length of a rent period in blocks.
```setBaseMintFee(uint256 _cost) external``` : Updates the fee to mint a new subscritipn token.
```rentPrice() external view returns(uint256)``` : Returns rent price.
```baseRentTime() external view returns(uint256)``` : Returns rent time in blocks.
```baseMintFee() external view returns(uint256)``` : Returns minting fee.
```getRentedBlocksRemaining(uint256 _tokenId)  public view returns (uint256)``` : Returns the amount of blocks remaining until the user's subscription is expired.
```payRent(uint256 _tokenId) external payable``` : Updates the rent for a token, based on ether sent to contract.
```ownerAllowedRent(uint256 _tokenId, uint256 _rentAdded) external``` : Allows contract owner to update rent for users. This can be utilized as a refund in the real world. For this project it is called in  ```SubscriptionManager.sol``` as a way to redeem loyalty points for rent.
```reclaim(uint256 _tokenId) external``` : The contract owner can call this function to transfer tokens that have not paid their rent back to the contract. 
```reclaimBatch(uint256[] calldata _tokenIds) external``` : Similar to ```reclaim()```, excpet ```reclaimBatch()``` is passed and array of tokenIds to be reclaimed by the contract.
```repurchase(uint256 _tokenId) external payable``` : Allows users to repurchase their reclaimed tokens. User must have the same address as when the token was reclaimed.
```function mint(address to) external payable``` : Adapted to require users to pay for their rent on minting. Also charges a fee to mint a subscription, this should incetivise repurchases over minting a new token.


```SubscriptionManager.sol``` is an example of how to implement ```LeaseERC721Facet.sol```. ```SubscriptionManager.sol``` periodically will check the user's status and either reclaim their NFT if the rent balance is 0, or reward the user with club tokens. ```ClubToken.sol``` is a basic ERC20 token that is used as a reward for the users` subscription. Users can then redeem free rent with their club tokens.

This implementation is a basic use case for a subscription NFT, but demonstrates its utility.

# NFT-Subscription-Service

TL;DR
A format for a NFT that can be used as proof of subscription. This implementation uses the Diamond Standard.

Using the Diamond Standard, to allow future contract upgrades, I created a subscription based protocol that uses a NFT as record of subscription. The NFT (```LeaseERC721Facet.sol```) is based off of OpenZepplin's ERC721 contract, but adapted to the Diamond Standard. ```LeaseERC721Facet.sol``` also adds the following functions that taylors its utility to a subscription model:


>> ```setRentPrice(uint256 _price) external``` : Updates the cost of rent for one rent period. <br />
>> ```setBaseRentTime(uint256 _blocks) external``` : Updates the length of a rent period in blocks. <br />
>> ```setBaseMintFee(uint256 _cost) external``` : Updates the fee to mint a new subscription token. <br />
>> ```rentPrice() external view returns(uint256)``` : Returns rent price. <br />
>> ```baseRentTime() external view returns(uint256)``` : Returns rent time in blocks. <br />
>> ```baseMintFee() external view returns(uint256)``` : Returns minting fee.
>> ```getRentedBlocksRemaining(uint256 _tokenId)  public view returns (uint256)``` : Returns the amount of blocks remaining until the user's subscription is expired. <br />
>> ```payRent(uint256 _tokenId) external payable``` : Updates the rent for a token, based on ether sent to contract. <br />
>> ```ownerAllowedRent(uint256 _tokenId, uint256 _rentAdded) external``` : Allows contract owner to update rent for users. This can be utilized as a refund in the real world. For this project it is called in  ```SubscriptionManager.sol``` as a way to redeem loyalty points for rent. <br />
>> ```reclaim(uint256 _tokenId) external``` : The contract owner can call this function to transfer tokens that have not paid their rent back to the contract. <br />
>> ```reclaimBatch(uint256[] calldata _tokenIds) external``` : Similar to ```reclaim()```, except ```reclaimBatch()``` is passed and array of tokenIds to be reclaimed by the contract. <br />
>> ```repurchase(uint256 _tokenId) external payable``` : Allows users to repurchase their reclaimed tokens. User must have the same address as when the token was reclaimed. <br />
>> ```function mint(address to) external payable``` : Adapted to require users to pay for their rent on minting. It also charges a fee to mint a subscription, this should incentivise repurchases over minting a new token. <br />


```SubscriptionManager.sol``` is an example of how to implement ```LeaseERC721Facet.sol```. ```SubscriptionManager.sol``` periodically will check the user's status and either reclaim their NFT if the rent balance is 0, or reward the user with club tokens. ```ClubToken.sol``` is a basic ERC20 token that is used as a reward for the users' subscription. Users can then redeem free rent with their club tokens.


This implementation is a basic use case for a subscription NFT, but demonstrates its utility.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract NFTWars is ERC721URIStorage {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    struct NFT {
        uint256 tokenId;
        uint256 timeLock;
        uint8 level;
        bool openForFight;
    }

    // Constants
    uint256 private constant FIGHT_TIME_LOCK = 1 days;
    uint256 private constant MINT_FEE = 0.2 ether;
    uint256 private constant FIGHT_FEE = 0.1 ether;

    mapping(uint256 => NFT) private warriors;

    modifier isLocked(uint256 _tokenId) {
        uint256 remainLockTime = warriors[_tokenId].timeLock;
        require(remainLockTime >= 0, "This NFT still locked.");
        _;
    }

    modifier isOwner(uint256 _tokenId) {
        require(
            ownerOf(_tokenId) == msg.sender,
            "You are not the owner of this NFT."
        );
        _;
    }

    modifier isNftExists(uint256 _tokenId) {
        require(_exists(_tokenId), "There is no token.");
        _;
    }

    constructor(uint64 _subscriptionId) ERC721("NFT Wars", "NFW") {}

    function attack(uint256 _tokenId, uint256 _toTokenId)
        external
        payable
        isLocked(_tokenId)
        isOwner(_tokenId)
        isNftExists(_tokenId)
    {
        require(msg.value >= FIGHT_FEE, "Insufficient funds.");
        require(
            warriors[_toTokenId].openForFight == true,
            "Enemy warrior is not open for fight."
        );
    }

    function openForFights(uint256 _tokenId)
        external
        payable
        isLocked(_tokenId)
        isOwner(_tokenId)
        isNftExists(_tokenId)
    {
        require(msg.value >= FIGHT_FEE, "Insufficient funds.");
        require(
            warriors[_tokenId].openForFight == false,
            "Warrior has already open for fight."
        );
        warriors[_tokenId].openForFight = true;
    }

    function getLevel(uint256 _tokenId) public view returns (string memory) {
        uint256 levels = warriors[_tokenId].level;
        return levels.toString();
    }

    function getTokenURI(uint256 _tokenId)
        internal
        view
        returns (string memory)
    {
        bytes memory dataURI = abi.encodePacked(
            "{",
            '"name": "Warrior #',
            _tokenId.toString(),
            '",',
            '"description": "Warriors of NFT",',
            '"image": "',
            generateCharacter(_tokenId),
            '"',
            "}"
        );
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(dataURI)
                )
            );
    }

    function generateCharacter(uint256 _tokenId)
        internal
        view
        returns (string memory)
    {
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
            "<style>.base { fill: white; font-family: serif; font-size: 14px; }</style>",
            '<rect width="100%" height="100%" fill="black" />',
            '<text x="50%" y="40%" class="base" dominant-baseline="middle" text-anchor="middle">',
            "Warrior",
            "</text>",
            '<text x="50%" y="50%" class="base" dominant-baseline="middle" text-anchor="middle">',
            "Levels: ",
            getLevel(_tokenId),
            "</text>",
            "</svg>"
        );
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xlm;base64,",
                    Base64.encode(svg)
                )
            );
    }

    function getMintFee() public pure returns (uint256) {
        return MINT_FEE;
    }

    function getLockedTime(uint256 _tokenId) public view returns (uint256) {
        return warriors[_tokenId].level;
    }

    function powerFromTimestamp() public view returns (uint256) {
        return block.timestamp % 100;
    }
}

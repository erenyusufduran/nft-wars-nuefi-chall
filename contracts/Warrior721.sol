// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Warrior721 is ERC721URIStorage, VRFConsumerBaseV2 {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event FightResulted(address indexed winner);

    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    address payable treasury;

    struct NFT {
        uint256 timeLock;
        uint256 power;
        uint256 strength;
        uint8 level;
        bool openForFight;
    }

    // Constants
    uint256 private constant FIGHT_TIME_LOCK = 1 minutes; // For testing, normally this might take 1 day.
    uint256 private constant MINT_FEE = 0.2 ether; // Mint fee for mint warrior.
    uint256 private constant FIGHT_FEE = 0.1 ether; // Fight fee for fighting bets.

    mapping(uint256 => NFT) private warriors; // TokenId to NFT properties.

    // Chainlink
    uint64 immutable i_subscriptionId; // subscription id from chainlink vrf
    address vrfCoordinator; // VRF Coordinator For Network
    bytes32 s_keyHash; // key hash for network
    uint32 constant callbackGasLimit = 300000;
    uint16 constant requestConfirmations = 3; // required request confirmations
    uint32 constant numWords = 1; // requested words count.

    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
        address requestOwner;
        uint256 requestTokenId;
    }

    mapping(uint256 => RequestStatus) public s_requests;
    VRFCoordinatorV2Interface COORDINATOR;
    uint256[] public requestIds;
    uint256 public lastRequestId;

    mapping(uint256 => bool) public tokenIdToRequest;

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

    constructor(
        uint64 _subscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash
    ) ERC721("Web3Warriors", "W3W") VRFConsumerBaseV2(_vrfCoordinator) {
        vrfCoordinator = _vrfCoordinator;
        s_keyHash = _keyHash;
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_subscriptionId = _subscriptionId;
        treasury = payable(msg.sender);
    }

    function mint() public {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(msg.sender, tokenId);
    }

    function updateMetadata(uint256 tokenId) public {
        require(warriors[tokenId].power > 0, "Have no response yet.");
        _setTokenURI(tokenId, getTokenURI(tokenId));
    }

    function requestRandomWords(uint256 tokenId)
        external
        payable
        returns (uint256 requestId)
    {
        require(!tokenIdToRequest[tokenId], "Request sent before.");
        require(msg.value >= MINT_FEE, "Insufficient funds.");
        require(
            msg.sender == ownerOf(tokenId),
            "You are not the owner of this NFT."
        );

        requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            i_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus(
            false,
            true,
            new uint256[](0),
            msg.sender,
            tokenId
        );
        requestIds.push(requestId);
        lastRequestId = requestId;
        tokenIdToRequest[tokenId] = true;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "Request not found!");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        uint256 powerFromVRF = _randomWords[0] % 100;
        uint256 strengthFromVRF = (_randomWords[0] / 10000) % 100;

        uint256 tokenId = s_requests[_requestId].requestTokenId;
        warriors[tokenId] = NFT(0, powerFromVRF, strengthFromVRF, 1, false);
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function attack(uint256 _tokenId, uint256 _toTokenId)
        external
        payable
        isLocked(_tokenId)
        isOwner(_tokenId)
        isNftExists(_tokenId)
    {
        require(getApproved(_tokenId) == address(this), "Need approval.");
        require(msg.value >= FIGHT_FEE, "Insufficient funds.");
        require(
            warriors[_toTokenId].openForFight == true,
            "Enemy warrior is not open for fight."
        );
        require(
            msg.sender != ownerOf(_toTokenId),
            "You can't fight with your own warriors."
        );
        require(tokenIdToRequest[_tokenId] && tokenIdToRequest[_toTokenId]);

        bool result = gameAlgorithm(_tokenId, _toTokenId);

        if (result) {
            increaseStatus(_tokenId);
            warriors[_tokenId].timeLock += FIGHT_TIME_LOCK;
            (bool sent, ) = payable(ownerOf(_tokenId)).call{
                value: (FIGHT_FEE * 17) / 10
            }("");
            require(sent, "Couldn't sent.");
            delete warriors[_toTokenId];
            _burn(_toTokenId);
            updateMetadata(_tokenId);
            emit FightResulted(msg.sender);
        } else {
            increaseStatus(_toTokenId);
            warriors[_toTokenId].timeLock += FIGHT_TIME_LOCK;
            (bool sent, ) = payable(ownerOf(_toTokenId)).call{
                value: (FIGHT_FEE * 19) / 10
            }("");
            require(sent, "Couldn't sent.");
            delete warriors[_toTokenId];
            _burn(_tokenId);
            updateMetadata(_toTokenId);
            emit FightResulted(ownerOf(_toTokenId));
        }
    }

    function gameAlgorithm(uint256 _from, uint256 _to)
        internal
        view
        returns (bool)
    {
        uint256 levelOfA = getLevel(_from);
        uint256 powerOfA = getPower(_from);
        uint256 strengthOfA = getStrength(_from);

        uint256 levelOfB = getLevel(_to);
        uint256 powerOfB = getPower(_to);
        uint256 strengthOfB = getStrength(_to);

        uint256 statusA = getStatus(levelOfA, powerOfA, strengthOfA);
        uint256 statusB = getStatus(levelOfB, powerOfB, strengthOfB);

        if (statusA > statusB) {
            return true;
        }
        return false;
    }

    function getStatus(
        uint256 level,
        uint256 power,
        uint256 strength
    ) internal pure returns (uint256) {
        return ((level * 11) / 10) + power * 4 + strength * 6;
    }

    function increaseStatus(uint256 _tokenId) internal {
        warriors[_tokenId].level += 1;
        warriors[_tokenId].power =
            (warriors[_tokenId].power * uint8(105)) /
            uint8(100);
        warriors[_tokenId].strength =
            (warriors[_tokenId].strength) *
            (uint8(105) / uint8(100));
    }

    function openForFights(uint256 _tokenId)
        external
        payable
        isLocked(_tokenId)
        isOwner(_tokenId)
        isNftExists(_tokenId)
    {
        require(getApproved(_tokenId) == address(this), "Need approval.");
        require(tokenIdToRequest[_tokenId]);
        require(msg.value >= FIGHT_FEE, "Insufficient funds.");
        require(
            warriors[_tokenId].openForFight == false,
            "Warrior has already open for fight."
        );
        warriors[_tokenId].openForFight = true;
    }

    function withdraw() external {
        require(msg.sender == treasury);
        (bool sent, ) = payable(treasury).call{
            value: (address(this).balance * 9) / 10
        }("");
        require(sent);
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
            "<style>.baseChar { fill: white; font-family: serif; font-size: 24px; }</style>",
            '<rect width="100%" height="100%" fill="black" />',
            '<text x="50%" y="29%" class="baseChar" dominant-baseline="middle" text-anchor="middle">',
            "Warrior",
            "</text>",
            '<text x="50%" y="45%" class="base" dominant-baseline="middle" text-anchor="middle">',
            "Level: ",
            getLevel(_tokenId).toString(),
            "</text>",
            '<text x="50%" y="55%" class="base" dominant-baseline="middle" text-anchor="middle">',
            "Power: ",
            getPower(_tokenId).toString(),
            "</text>",
            '<text x="50%" y="65%" class="base" dominant-baseline="middle" text-anchor="middle">',
            "Strength: ",
            getStrength(_tokenId).toString(),
            "</text>",
            "</svg>"
        );
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(svg)
                )
            );
    }

    function getPower(uint256 _tokenId) public view returns (uint256) {
        uint256 power = warriors[_tokenId].power;
        return power;
    }

    function getStrength(uint256 _tokenId) public view returns (uint256) {
        uint256 strength = warriors[_tokenId].strength;
        return strength;
    }

    function getLevel(uint256 _tokenId) public view returns (uint256) {
        uint256 level = warriors[_tokenId].level;
        return level;
    }

    function getMintFee() public pure returns (uint256) {
        return MINT_FEE;
    }

    function getLockedTime(uint256 _tokenId) public view returns (uint256) {
        return warriors[_tokenId].timeLock;
    }
}

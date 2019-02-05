pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../generators/HeadToHeadResulter.sol";

contract IAttributesNft is IERC721 {
    function attributesFlat(uint256 _tokenId) external view returns (uint256[] memory attributes);
}

contract HeadToHead is Ownable, Pausable {
    using SafeMath for uint256;

    event GameCreated(uint256 indexed gameId, address indexed home, uint256 indexed _homeTokenId);
    event GameResulted(address indexed home, address indexed away, uint256 indexed gameId, uint256 result);
    event GameDraw(address indexed home, address indexed away, uint256 indexed gameId, uint256 result);
    event GameClosed(uint256 indexed gameId, address indexed closer);

    enum State {OPEN, HOME_WIN, AWAY_WIN, DRAW, CLOSED}

    struct Game {
        uint256 id;
        uint256 homeTokenId;
        address homeOwner;
        uint256 awayTokenId;
        address awayOwner;
        State state;
    }

    // Start at 1 so we can use Game ID 0 to identify not set
    uint256 public totalGames = 1;

    mapping(uint256 => Game) games;

    IAttributesNft public nft;
    HeadToHeadResulter public resulter;

    /////////////////
    // Constructor //
    /////////////////

    constructor (HeadToHeadResulter _resulter, IAttributesNft _nft) public {
        resulter = _resulter;
        nft = _nft;
    }

    ///////////////
    // Modifiers //
    ///////////////

    modifier onlyWhenTokenOwner(uint256 _tokenId) {
        require(nft.ownerOf(_tokenId) == msg.sender, "You cannot enter if you dont own the card");
        _;
    }

    modifier onlyWhenContractIsApproved() {
        require(nft.isApprovedForAll(msg.sender, address(this)), "NFt not approved to play yet");
        _;
    }

    modifier onlyWhenRealGame(uint256 _gameId) {
        require(games[_gameId].id > 0, "Game not setup");
        _;
    }

    modifier onlyWhenGameOpen(uint256 _gameId) {
        require(games[_gameId].state == State.OPEN, "Game not open");
        _;
    }

    modifier onlyWhenGameDrawn(uint256 _gameId) {
        require(games[_gameId].state == State.DRAW, "Game not in drawn state");
        _;
    }

    modifier onlyWhenGameNotComplete(uint256 _gameId) {
        require(games[_gameId].state == State.DRAW || games[_gameId].state == State.OPEN, "Game not open");
        _;
    }

    ///////////////
    // Functions //
    ///////////////

    function createGame(uint256 _tokenId)
    whenNotPaused
    onlyWhenContractIsApproved
    onlyWhenTokenOwner(_tokenId)
    public returns (uint256 _gameId) {

        uint256 gameId = totalGames;

        games[totalGames] = Game({
            id : gameId,
            homeTokenId : _tokenId,
            homeOwner : msg.sender,
            awayTokenId : 0,
            awayOwner : address(0),
            state : State.OPEN
            });

        totalGames = totalGames.add(1);

        emit GameCreated(gameId, msg.sender, _tokenId);

        return gameId;
    }

    // TODO check token not used in another game

    function resultGame(uint256 _gameId, uint256 _tokenId)
    whenNotPaused
    onlyWhenContractIsApproved
    onlyWhenTokenOwner(_tokenId)
    onlyWhenRealGame(_gameId)
    onlyWhenGameOpen(_gameId)
    public returns (bool) {

        // Ensure you can win at least on one attribute
        uint256[] memory home = nft.attributesFlat(games[_gameId].homeTokenId);
        uint256[] memory away = nft.attributesFlat(_tokenId);

        bool hasAtLeastSlimChanceOfWinning = false;
        for (uint i = 0; i < home.length; i++) {
            if (home[i] < away[i]) {
                hasAtLeastSlimChanceOfWinning = true;
                break;
            }
        }
        require(hasAtLeastSlimChanceOfWinning, "There is no chance of winning");

        games[_gameId].awayTokenId = _tokenId;
        games[_gameId].awayOwner = msg.sender;

        _resultGame(_gameId);

        return true;
    }

    function reMatch(uint256 _gameId)
    whenNotPaused
    onlyWhenContractIsApproved
    onlyWhenRealGame(_gameId)
    onlyWhenGameDrawn(_gameId)
    public returns (bool) {

        _resultGame(_gameId);

        return true;
    }

    function withdrawFromGame(uint256 _gameId)
    whenNotPaused
    onlyWhenRealGame(_gameId)
    onlyWhenGameNotComplete(_gameId)
    public returns (bool) {
        require(games[_gameId].homeOwner == msg.sender || games[_gameId].awayOwner == msg.sender, "Cannot close a game you are not part of");

        games[_gameId].state = State.CLOSED;

        emit GameClosed(_gameId, msg.sender);

        return true;
    }

    function _resultGame(uint256 _gameId) internal {
        address homeOwner = games[_gameId].homeOwner;
        uint256 homeTokenId = games[_gameId].homeTokenId;

        address awayOwner = games[_gameId].awayOwner;
        uint256 awayTokenId = games[_gameId].awayTokenId;

        // indexes are zero based
        uint256 result = resulter.result(_gameId, msg.sender).sub(1);

        uint256[] memory home = nft.attributesFlat(homeTokenId);
        uint256[] memory away = nft.attributesFlat(awayTokenId);

        if (home[result] > away[result]) {
            nft.safeTransferFrom(awayOwner, homeOwner, awayTokenId);
            games[_gameId].state = State.HOME_WIN;

            emit GameResulted(homeOwner, awayOwner, _gameId, result);
        }
        else if (home[result] < away[result]) {
            nft.safeTransferFrom(homeOwner, awayOwner, homeTokenId);
            games[_gameId].state = State.AWAY_WIN;

            emit GameResulted(homeOwner, awayOwner, _gameId, result);
        }
        else {
            // Allow a re-match if no winner found
            games[_gameId].state = State.DRAW;

            emit GameDraw(homeOwner, awayOwner, _gameId, result);
        }
    }

}
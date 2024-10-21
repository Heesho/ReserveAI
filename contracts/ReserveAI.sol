// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAIOracle {
    /// @notice Event emitted upon receiving a callback request through requestCallback.
    event AICallbackRequest(
        address indexed account,
        uint256 indexed requestId,
        uint256 modelId,
        bytes input,
        address callbackContract,
        uint64 gasLimit,
        bytes callbackData
    );

    /// @notice Event emitted when the result is uploaded or update.
    event AICallbackResult(
        address indexed account,
        uint256 indexed requestId,
        address invoker,
        bytes output
    );

    /**
     * initiate a request in OAO
     * @param modelId ID for AI model
     * @param input input for AI model
     * @param callbackContract address of callback contract
     * @param gasLimit gas limitation of calling the callback function
     * @param callbackData optional, user-defined data, will send back to the callback function
     * @return requestID
     */
    function requestCallback(
        uint256 modelId,
        bytes memory input,
        address callbackContract,
        uint64 gasLimit,
        bytes memory callbackData
    ) external payable returns (uint256);

    function estimateFee(uint256 modelId, uint256 gasLimit) external view returns (uint256);

    function isFinalized(uint256 requestId) external view returns (bool);
}

/// @notice A base contract for writing a AIOracle app
abstract contract AIOracleCallbackReceiver {

    // Address of the AIOracle contract
    IAIOracle public immutable aiOracle;

    // Invalid callback source error
    error UnauthorizedCallbackSource(IAIOracle expected, IAIOracle found);

    /// @notice Initialize the contract, binding it to a specified AIOracle contract
    constructor(IAIOracle _aiOracle) {
        aiOracle = _aiOracle;
    }

    /// @notice Verify this is a callback by the aiOracle contract 
    modifier onlyAIOracleCallback() {
        IAIOracle foundRelayAddress = IAIOracle(msg.sender);
        if (foundRelayAddress != aiOracle) {
            revert UnauthorizedCallbackSource(aiOracle, foundRelayAddress);
        }
        _;
    }

    /**
     * @dev the callback function in OAO, should add the modifier onlyAIOracleCallback!
     * @param requestId Id for the request in OAO (unique per request)
     * @param output AI model's output
     * @param callbackData user-defined data (The same as when the user call aiOracle.requestCallback)
     */
    function aiOracleCallback(uint256 requestId, bytes calldata output, bytes calldata callbackData) external virtual;

    function isFinalized(uint256 requestId) external view returns (bool) {
        return aiOracle.isFinalized(requestId);
    }
}

contract ReserveAI is AIOracleCallbackReceiver, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /*----------  CONSTANTS  --------------------------------------------*/

    uint256 public constant MODEL_ID = 11; // Llama 3.1

    /*----------  STATE VARIABLES  --------------------------------------*/

    address public immutable rai;
    address public immutable base;
    address public immutable lp;

    struct AIOracleRequest {
        address sender;
        uint256 modelId;
        bytes input;
        bytes output;
    }

    mapping(uint256 => AIOracleRequest) public requests;     // requestId => AIOracleRequest
    mapping(uint256 => uint64) public callbackGasLimit;    // modelId => callback gasLimit
    mapping(uint256 => mapping(string => string)) public prompts; // modelId => (prompt => output)

    /*----------  ERRORS ------------------------------------------------*/

    /*----------  EVENTS ------------------------------------------------*/

    event promptsUpdated(
        uint256 requestId,
        uint256 modelId,
        string input,
        string output,
        bytes callbackData
    );

    event promptRequest(
        uint256 requestId,
        address sender, 
        uint256 modelId,
        string prompt
    );

    /*----------  FUNCTIONS  --------------------------------------------*/

    constructor(IAIOracle _aiOracle, address _rai, address _base, address _lp) AIOracleCallbackReceiver(_aiOracle) {
        rai = _rai;
        base = _base;
        lp = _lp;

        callbackGasLimit[11] = 5_000_000; // Llama 3.1
    }

    function contribute(uint256 amount, string calldata prompt) payable external {

        address account = msg.sender;
        uint256 raiHoldings = IERC20(rai).balanceOf(account);
        uint256 lpHoldings = IERC20(lp).balanceOf(account);
        uint256 raiSupply = IERC20(rai).totalSupply();
        uint256 lpSupply = IERC20(lp).totalSupply();
        // uint256 price = get price from lp

        constructPrompt(amount, raiHoldings, lpHoldings, raiSupply, lpSupply, prompt);

        bytes memory input = bytes(prompt);
        // we do not need to set the callbackData in this example
        uint256 requestId = aiOracle.requestCallback{value: msg.value}(
            MODEL_ID, input, address(this), callbackGasLimit[MODEL_ID], ""
        );
        AIOracleRequest storage request = requests[requestId];
        request.input = input;
        request.sender = msg.sender;
        request.modelId = MODEL_ID;
        emit promptRequest(requestId, msg.sender, MODEL_ID, prompt);

        // TODO: transfer weth from sender to this contract
    }

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/

    function constructPrompt(uint256 amount, uint256 raiHoldings, uint256 lpHoldings, uint256 raiSupply, uint256 lpSupply, string memory prompt) internal view returns (string memory) {
        // TODO: construct the prompt
        return "";
    }

    // the callback function, only the AI Oracle can call this function
    function aiOracleCallback(uint256 requestId, bytes calldata output, bytes calldata callbackData) external override onlyAIOracleCallback() {
        // since we do not set the callbackData in this example, the callbackData should be empty
        AIOracleRequest storage request = requests[requestId];
        require(request.sender != address(0), "request not exists");
        request.output = output;
        prompts[request.modelId][string(request.input)] = string(output);
        emit promptsUpdated(requestId, request.modelId, string(request.input), string(output), callbackData);

        // TODO: mint rai to the sender based on the output
    }

    function setCallbackGasLimit(uint64 gasLimit) external onlyOwner {
        callbackGasLimit[MODEL_ID] = gasLimit;
    }

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/

    function getAIResult(string calldata prompt) external view returns (string memory) {
        return prompts[MODEL_ID][prompt];
    }

    function estimateFee() public view returns (uint256) {
        return aiOracle.estimateFee(MODEL_ID, callbackGasLimit[MODEL_ID]);
    }
    
}
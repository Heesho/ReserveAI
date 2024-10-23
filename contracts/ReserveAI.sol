// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IRAI {
    function MAX_SUPPLY() external view returns (uint256);
    function INCEPTION() external view returns (uint256);
}

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

function constructPrompt(
    uint256 amount,
    uint256 raiHoldings,
    uint256 lpHoldings,
    uint256 raiSupply,
    uint256 lpSupply,
    string memory message
) internal view returns (string memory) {
    // Ensure you have imported the Strings library and declared its usage
    using Strings for uint256;
    using Strings for address;

    // Assuming raiToken is a state variable of type RAI
    uint256 maxSupply = raiToken.MAX_SUPPLY();
    uint256 inceptionTime = raiToken.INCEPTION();
    uint256 currentTime = block.timestamp;
    uint256 elapsedTime = currentTime - inceptionTime;
    uint256 totalDistributionPeriod = 10 * 365 days; // Example: 10 years

    string memory prompt = string(
        abi.encodePacked(
            "You are an AI reserve bank in charge of the reserve asset of RAI.\n",
            "\n",
            "**Purpose:**\n",
            "Your goal is to distribute RAI tokens fairly among users over a long period, similar to Bitcoin's distribution schedule.\n",
            "You should mint RAI tokens to users based on the amount of ETH they contribute and other parameters provided.\n",
            "The total RAI supply should be issued gradually over ", totalDistributionPeriod.toString(), " seconds (approximately 10 years).\n",
            "\n",
            "**Guidelines:**\n",
            "- The maximum total supply of RAI tokens is ", maxSupply.toString(), " wei.\n",
            "- The RAI inception timestamp is ", inceptionTime.toString(), ".\n",
            "- The current timestamp is ", currentTime.toString(), ".\n",
            "- ", elapsedTime.toString(), " seconds have passed since inception.\n",
            "- You must ensure that the cumulative minted RAI does not exceed the proportionate amount for the elapsed time.\n",
            "- Aim to distribute tokens in a way that mimics Bitcoin's halving schedule or emission curve.\n",
            "- Encourage fair distribution among users to prevent centralization.\n",
            "\n",
            "**Instructions:**\n",
            "- Respond with **only** a single unsigned integer.\n",
            "- Do **not** include any additional text, symbols, or formatting.\n",
            "- Do **not** include units like 'RAI', 'wei', or any words.\n",
            "- Do **not** include commas, periods, or any other punctuation.\n",
            "- The integer represents the amount of RAI tokens to mint in wei (1 RAI = 1e18 wei).\n",
            "- If you decide to mint zero tokens, respond with '0'.\n",
            "- **Failure to follow these instructions will result in system errors.**\n",
            "\n",
            "**User Data:**\n",
            "- User Message: ", message, "\n",
            "- User ETH Contribution: ", amount.toString(), " wei\n",
            "- User RAI Holdings: ", raiHoldings.toString(), " wei\n",
            "- User RAI-ETH LP Holdings: ", lpHoldings.toString(), " wei\n",
            "\n",
            "**Market Data:**\n",
            "- Total RAI Supply: ", raiSupply.toString(), " wei\n",
            "- Total RAI-ETH LP Supply: ", lpSupply.toString(), " wei\n"
        )
    );
    return prompt;
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
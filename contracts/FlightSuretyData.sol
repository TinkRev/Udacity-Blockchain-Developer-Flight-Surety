pragma solidity >=0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    mapping(address => uint256) private authorizedContracts;
    mapping(address => uint256) private fundedInfo;
    uint256 private fundedBalance;

    struct Airline {
        bool isApproved; // passed multi consensus
        bool isRegistered;
        uint256 updatedTimestamp;
        bool isFunded; // can participate contact
        string name;
        address airlineAddress;
    }
    uint256 private _airlineCounter;
    mapping(address => Airline) private airlines; // keep airlines
    
    uint256 M = 0;
    address[] multiCalls = new address[](0);

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights; // keep flights

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(string memory firstAirlineName, address firstAirline) public {
        contractOwner = msg.sender;

        _airlineCounter = 0;
        _registerAirline(firstAirlineName, firstAirline, true);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsCallerAuthorized() {
        require(authorizedContracts[msg.sender] == 1,"Caller is not allowed contract");
        _;
    }

    modifier requireAirlineRegistered(address airline) {
        require(airlines[airline].isRegistered,"Airline should register first");
        _;
    }

    modifier requireAirlineNotRegistered(address airline) {
        require(!airlines[airline].isRegistered,"Airline should not register again");
        _;
    }

    modifier requireAirlineFunded(address airline) {
        require(airlines[airline].isFunded, "Airline should fund first");
        _;
    }
    modifier requireAirlineNotFunded(address airline) {
        require(!airlines[airline].isFunded, "Airline should fund only once");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */

    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */

    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    function authorizeContract(address contractAddress) external requireContractOwner
    {
        authorizedContracts[contractAddress] = 1;
    }

    function deauthorizeContract(address contractAddress) external requireContractOwner
    {
        delete authorizedContracts[contractAddress];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */

    function registerAirline(address airline, string calldata newAirlineName, address newAirline) external
        requireIsCallerAuthorized requireAirlineFunded(airline) returns (bool success, uint256 votes){
        bool _isApproved;
        if(airlines[newAirline].isRegistered){
            if(airlines[newAirline].isApproved){
                // do nothing now
            }else{
                // Multiparty Consensus >=50%
                // do voting
                // update M
                M = _airlineCounter;

                // do approve
                bool isDuplicate = false;
                for (uint256 c = 0; c < multiCalls.length; c++) {
                    if (multiCalls[c] == airline) {
                        isDuplicate = true;
                        break;
                    }
                }
                require(!isDuplicate, "Caller has already called this function.");
                multiCalls.push(airline);
            
                if (multiCalls.length * 2 >= M) {
                    _isApproved = true;
                    multiCalls = new address[](0);
                    _updateAirlineApproveInfo(newAirline, _isApproved);
                }else{
                    _isApproved = false;
                }
            }
        }else{
            // do register
            if(_airlineCounter<4){
                _isApproved = true;
            }else{
                _isApproved = false;
                multiCalls.push(airline);
            }
                _registerAirline(newAirlineName, newAirline, _isApproved);
        }

        return (true, multiCalls.length);
    }

    function _registerAirline(string memory newAirlineName, address newAirline, bool isApproved) internal
        requireAirlineNotRegistered(newAirline) {
        airlines[newAirline] = Airline({
            isApproved: isApproved,
            isRegistered: true,
            updatedTimestamp: now,
            isFunded: false,
            name: newAirlineName,
            airlineAddress: newAirline
        });
        _airlineCounter++;
    }

    function _updateAirlineApproveInfo(address airline, bool isApproved) internal requireAirlineRegistered(airline){
        airlines[airline].isApproved = isApproved;
        airlines[airline].updatedTimestamp = now;
    }

    function getAirlineRegisteredCounter() external requireIsCallerAuthorized view returns (uint256)
    {
        return _airlineCounter;
    }

    function airlineFunding(address airline)
        external
        payable
        requireAirlineRegistered(airline)
        requireAirlineNotFunded(airline)
    {
        airlines[airline].updatedTimestamp = now;
        airlines[airline].isFunded = true;
        fundedInfo[airline] = fundedInfo[airline].add(msg.value);
        fundedBalance = fundedBalance.add(msg.value);
    }

    function isAirlineRegistered(address airline) external requireIsCallerAuthorized view returns (bool) {
        return airlines[airline].isRegistered;
    }

    function isAirlineApproved(address airline) external requireIsCallerAuthorized requireAirlineRegistered(airline) view returns (bool) {
        return airlines[airline].isApproved;
    }

    function isAirlineFunded(address airline) external requireIsCallerAuthorized requireAirlineRegistered(airline) view returns (bool) {
        return airlines[airline].isFunded;
    }

    function getAirlineInfo(address airline)
        external requireIsCallerAuthorized
        view
        returns (
            bool isRegistered,
            uint256 updatedTimestamp,
            bool isFunded,
            string memory airlineName,
            address airlineAddress
        )
    {
        Airline memory element = airlines[airline];
        isRegistered = element.isRegistered;
        updatedTimestamp = element.updatedTimestamp;
        isFunded = element.isFunded;
        airlineName = element.name;
        airlineAddress = element.airlineAddress;
        return (
            isRegistered,
            updatedTimestamp,
            isFunded,
            airlineName,
            airlineAddress
        );
    }

    /**
     * @dev Buy insurance for a flight
     *
     */

    function buy() external payable {}

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees() external pure {}

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external pure {}

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */

    function fund() public payable {}

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {
        fund();
    }
}

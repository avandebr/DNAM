pragma solidity ^0.5.0;

import './AccessRestricted.sol';
import './FiatContract.sol';

contract Patenting is AccessRestricted {

    // TODO: add text to require
    // TODO: remove deposit in Request

    uint public depositPrice;
    // uint public newVersionPrice;

    enum RequestStatus {NotRequested, Pending, Rejected, Cancelled, Accepted}

    /* Struct for request */
    struct Request {
        RequestStatus status;
        uint8 acceptedLicence;
        uint8 requestedLicence;
        uint deposit;
        string email;
        string encryptionKey;
        string encryptedIpfsKey;
    }

    // mapping(address => string[]) requestedPatents; // address to requested patentIDs

    /* Struct for patent */
    struct Patent {
        string name;
        address owner;
        // string parentHash;
        uint timestamp; // uint64
        string ipfs;
        uint8 maxLicence;
        uint[] licencePrices;
        bool deleted;
        address[] buyers;
        mapping(address => Request) requests;
        // mapping(address => bool) rates;
    }

    string[] public patentIDs; // patent hashes
    mapping(string => Patent) private patents; // patent ID (hash) to Patents

    /* Struct for user account */
    struct User {
        string name;
        string email;
        uint createdAt;
        string[] ownedPatentIDs;
    }

    address[] public userIDs; // user addresses
    mapping(address => User) private users; // user ID (address) to User

    // TODO: add _patentID and licences in events

    event NewRequest(
        string _ownerMail,
        string _patentName,
        address _rentee
    );

    event RequestResponse(
        string _requesterEmail,
        string _patentName,
        bool _accepted
    );

    FiatContract fiat;

    /* Constructor of the contract
    * {param} uint : The price for depositing a pattern in Wei
    */
    constructor(uint _depositPrice, address _fiatContract) public {
        fiat = FiatContract(_fiatContract);
        depositPrice = _depositPrice;
    }

    /*Allows the owner to withdraw the remaining funds*/
    function withdrawFunds() public onlyOwner {
        owner.transfer(address(this).balance);
    }

    /*Allows the owner to modify the price to deposit a new patent*/
    function setDepositPrice(uint _newPrice) public onlyOwner {
        depositPrice = _newPrice;
    }

    /*Allows the owner to modify the price to deposit a new patent*/
    /*function setNewVersionPrice(uint _newPrice) public onlyOwner {
        newVersionPrice = _newPrice;
    }*/

    /*Allows the owner to modify the price to deposit a new patent*/
    /*function setFiatAddress(uint _newAddress) public onlyOwner {
        fiat = FiatContract(_newAddress);
    }*/

    function getEthPrice(uint _dollars) public view returns (uint) {
        return fiat.USD(0) * 100 * _dollars;
        // return _dollars / 130;
    }

    /* ========================================= USER MANAGEMENT FUNCTIONS ======================================== */

    /* Function to register a new user */
    function registerAccount(string memory _name, string memory _email) public {
        require(!hasAccount(msg.sender));
        users[msg.sender] = User(_name, _email, now, new string[](0));
        userIDs.push(msg.sender);
        // emit newAccount
    }

    /* Function to modify the user information */
    function modifyAccount(string memory _newName, string memory _newEmail) public {
        // require(hasAccount(msg.sender) && (!equalStrings(_newName, users[msg.sender].name) || !equalStrings(_newEmail, users[msg.sender].email)));
        User storage u = users[msg.sender];
        u.name = _newName;
        u.email = _newEmail;
    }

    /*function equalStrings(string memory a, string memory b) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))) );
    }*/

    /* ======================================== PATENT MANAGEMENT FUNCTIONS ======================================= */

    /* Function to deposit a patent
    * {params} the patent parameters
    * {costs} the price of a patent
    */
    function depositPatent(string memory _patentName, string memory _patentHash, uint8 _maxLicence, uint[] memory _licencePrices, string memory _ipfs) public payable {
        require(hasAccount(msg.sender) && !isRegistered(_patentHash) && msg.value >= getEthPrice(depositPrice) && _licencePrices.length == _maxLicence);
        patents[_patentHash] = Patent(_patentName, msg.sender, now, _ipfs, _maxLicence, _licencePrices, false, new address[](0));
        patentIDs.push(_patentHash);
        User storage u = users[msg.sender];
        u.ownedPatentIDs.push(_patentHash);
        // emit event
    }

    /* Function to modify the licences and prices of a patent */
    function modifyPatent(string memory _patentID, string memory _newName, uint8 _newMaxLicence, uint[] memory _newLicencePrices) public {
        require(isRegistered(_patentID) && isOwner(_patentID, msg.sender));
        Patent storage p = patents[_patentID];
        p.name = _newName;
        p.maxLicence = _newMaxLicence;
        p.licencePrices = _newLicencePrices;
    }

    /* delete or undelete a patent (i.e. set its visibility wrt other users) */
    function setVisibility(string memory _patentID) public {
        require(isRegistered(_patentID) && isOwner(_patentID, msg.sender));
        Patent storage p = patents[_patentID];
        p.deleted = !p.deleted;
    }

    /* ======================================== REQUEST MANAGEMENT FUNCTIONS ======================================= */

    /* Function to request access to a patent
    * {params} _patentName : name of patent
    *          _requestedLicence : licence requested for the patent
    *          _encryptionKey : key to encrypt AES key with (key exchange protocol)
    * {costs} price of the patent : will be frozen until request is accepted, rejected, or cancelled
    */
    function requestAccess(string memory _patentID, uint8 _requestedLicence, string memory _encryptionKey, string memory _email) public payable {
        require(isRegistered(_patentID) && canRequest(_patentID, _requestedLicence, msg.sender));
        // require patent has not already been requested
        require(patents[_patentID].requests[msg.sender].status == RequestStatus.NotRequested);
        uint ethPrice = getEthPrice(getPrice(_patentID, _requestedLicence));
        require(msg.value >= ethPrice);
        // requestedPatents[msg.sender].push(_patentID);
        Patent storage p = patents[_patentID];
        p.buyers.push(msg.sender);
        p.requests[msg.sender] = Request(RequestStatus.Pending, 0, _requestedLicence, ethPrice, _email, _encryptionKey, "");
        emit NewRequest(getOwnerEmail(_patentID), patents[_patentID].name, msg.sender); // put licence in event
    }

    /* Resend a request for a patent (either to upgrade licence for an accepted request or
    *  to request access for a previously rejected or cancelled request)
    */
    function resendRequest(string memory _patentID, uint8 _requestedLicence) public payable {
        require(isRegistered(_patentID) && canRequest(_patentID, _requestedLicence, msg.sender));
        // Ensure patent has already been requested
        require(patents[_patentID].requests[msg.sender].status != RequestStatus.NotRequested);
        uint price = getPrice(_patentID, _requestedLicence);
        uint8 userLicence = patents[_patentID].requests[msg.sender].acceptedLicence;
        if (userLicence > 0) {
            // just pay the difference if the user has already access to a licence
            price -= getPrice(_patentID, userLicence);
        }
        uint ethPrice = getEthPrice(price);
        require(msg.value >= ethPrice);
        Request storage r = patents[_patentID].requests[msg.sender];
        r.status = RequestStatus.Pending;
        r.requestedLicence = _requestedLicence;
        r.deposit = ethPrice;
        emit NewRequest(getOwnerEmail(_patentID), patents[_patentID].name, msg.sender); // put licence in event and parameter isNew ?
    }

    /* Function to accept a request
    * {params} _patentID : id of patent
    *          _user : user to give access to (must have requested)
    *   Transfers the amount to the patent owner
    */
    function acceptRequest(string memory _patentID, address _user) public {
        require(isRegistered(_patentID) && isOwner(_patentID, msg.sender) && isPending(_patentID, _user));
        Request storage r = patents[_patentID].requests[_user];
        // require(r.deposit >= 0);
        msg.sender.transfer(r.deposit);
        r.deposit = 0;
        r.status = RequestStatus.Accepted;
        r.acceptedLicence = r.requestedLicence;
        emit RequestResponse(r.email, patents[_patentID].name, true); // put licence in event
    }

    /* Function to grant access to a user
    * {params} _patentID : id of patent
    *          _user : user to give access to (must have requested)
    *          _encryptedIpfsKey : encrypted AES key to decrypt file on ipfs
    *   accept the pending request and gives the key to the requester
    */
    function grantAccess(string memory _patentID, address _user, string memory _encryptedIpfsKey) public {
        acceptRequest(_patentID, _user);
        Request storage r = patents[_patentID].requests[_user];
        r.encryptedIpfsKey = _encryptedIpfsKey;
    }

    /* Function to reject access to a patent or a licence upgrade
    * {params} : Same as above
    * Refunds the amount to the user
    */
    function rejectRequest(string memory _patentID, address payable _user) public {
        require(isRegistered(_patentID) && isOwner(_patentID, msg.sender) && isPending(_patentID, _user));
        Request storage r = patents[_patentID].requests[_user];
        // require(r.deposit >= 0);
        // Refund back to user
        _user.transfer(r.deposit);
        r.deposit = 0;
        // if user already had access (i.e. asked for upgrade), just go back to previously accepted licence, otherwise reject
        uint8 userLicence = patents[_patentID].requests[msg.sender].acceptedLicence;
        if (userLicence > 0) {
            r.status = RequestStatus.Accepted;
        } else {
            r.status = RequestStatus.Rejected;
        }
        emit RequestResponse(r.email, patents[_patentID].name, false); // Put licence in event
    }

    /* Function that cancels a request (can only be called by user)
    * {params} : _patentName : name of patent
    */
    function cancelRequest(string memory _patentID) public {
        require(isRegistered(_patentID) && isPending(_patentID, msg.sender));
        Request storage r = patents[_patentID].requests[msg.sender];
        // require(r.deposit >= 0);
        // Refund back to user
        msg.sender.transfer(r.deposit);
        r.deposit = 0;
        uint8 userLicence = patents[_patentID].requests[msg.sender].acceptedLicence;
        if (userLicence > 0) {
            r.status = RequestStatus.Accepted;
        } else {
            r.status = RequestStatus.Cancelled;
        }
    }

    /* ============================== View functions that do not require transactions ============================== */


    /*Returns number of deposited patents*/
    function patentCount() public view returns (uint){
        return patentIDs.length;
    }

    /*Returns number of registered users*/
    function userCount() public view returns (uint){
        return userIDs.length;
    }

    /*Returns true if the given account can request the given patent*/
    function canRequest(string memory _patentID, uint _requestedLicence, address _user) public view returns (bool){
        return !patents[_patentID].deleted && !isPending(_patentID, _user) && !isOwner(_patentID, _user)
            && _requestedLicence > patents[_patentID].requests[msg.sender].acceptedLicence
            && _requestedLicence <= patents[_patentID].maxLicence;
    }

    function getRequestInformation(string memory _patentID, address _user) public view returns (RequestStatus, uint8, uint8, string memory) {
        Request memory r = patents[_patentID].requests[_user];
        return (r.status, r.acceptedLicence, r.requestedLicence, r.email);
    }

    function getPatentInformation(string memory _patentID) public view returns (string memory, address, uint, string memory, uint8, uint[] memory, bool) {
        Patent memory p = patents[_patentID];
        return (p.name, p.owner, /*p.parentHash,*/ p.timestamp, p.ipfs, p.maxLicence, p.licencePrices, p.deleted);
    }

    function getUserInformation(address _userID) public view returns (string memory, string memory) {
        User memory u = users[_userID];
        return (u.name, u.email);
    }

    /*Returns true of the given account has a pending request on the given patent*/
    function isPending(string memory _patentID, address _user) public view returns (bool){
        return patents[_patentID].requests[_user].status == RequestStatus.Pending;
    }

    /*Returns true if account is owner of given patent*/
    function isOwner(string memory _patentID, address _user) public view returns (bool){
        return patents[_patentID].owner == _user;
    }

    /*Returns the price of a patent for a given licence*/
    function getPrice(string memory _patentID, uint _licence) public view returns (uint) {
        // index by licence-1 cause licence 0 price not stored in licence prices since free
        return patents[_patentID].licencePrices[_licence-1];
    }

    /*Returns the number of requests for the given patent*/
    function getNumRequests(string memory _patentID) public view returns (uint){
        return patents[_patentID].buyers.length;
    }

    /*Returns the address of the buyer at _index  (Used for iterating)*/
    function getBuyers(string memory _patentID, uint _index) public view returns (address){
        return patents[_patentID].buyers[_index];
    }

    /*Returns the address of the buyer at _index  (Used for iterating)*/
    /* function getNumRequestedPatents() public view returns (uint){
        return requestedPatents[msg.sender].length;
    } */

    /*Returns the address of the buyer at _index  (Used for iterating)*/
    /* function getRequestedPatents(uint _index) public view returns (string memory){
        return requestedPatents[msg.sender][_index];
    }*/

    /*Returns the requester's public key*/
    function getEncryptionKey(string memory _patentID, address _user) public view returns (string memory){
        return patents[_patentID].requests[_user].encryptionKey;
    }

    /*Returns the encrypted IPFS AES key*/
    function getEncryptedIpfsKey(string memory _patentID) public view returns (string memory){
        require(patents[_patentID].requests[msg.sender].status == RequestStatus.Accepted);
        return patents[_patentID].requests[msg.sender].encryptedIpfsKey;
    }

    /*Returns the email address of the _patentID's owner*/
    function getOwnerEmail(string memory _patentID) public view returns (string memory) {
        return users[patents[_patentID].owner].email;
    }

    /*Returns true if the given patent ID has already been registered*/
    function isRegistered(string memory _patentID) public view returns (bool) {
        return patents[_patentID].timestamp != 0;
    }

    /*Returns true if the given account has already been registered*/
    function hasAccount(address _user) public view returns (bool) {
        return users[_user].createdAt != 0;
    }

    /*Returns the number of patents owned by the user*/
    function getNumPatents(address _user) public view returns (uint){
        return users[_user].ownedPatentIDs.length;
    }

    /*Returns the patent of the _user at index i (Used for iterating)*/
    function getOwnedPatentIDs(address _user, uint _index) public view returns (string memory){
        return users[_user].ownedPatentIDs[_index];
    }
}

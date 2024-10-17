// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    // State variables
    address[] public owners;
    uint256 public requiredConfirmations;
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    uint256 public transactionCount;

    struct Transaction {
        address to;
        uint256 value;
        bool executed;
    }

    event Deposit(address indexed sender, uint256 value);
    event Submit(uint256 indexed transactionId, address indexed to, uint256 value);
    event Confirm(uint256 indexed transactionId, address indexed owner);
    event Execute(uint256 indexed transactionId);
    event Revoke(uint256 indexed transactionId, address indexed owner);

    modifier onlyOwner() {
        require(isOwner(msg.sender), "Not owner");
        _;
    }

    modifier txExists(uint256 transactionId) {
        require(transactionId < transactionCount, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 transactionId) {
        require(!confirmations[transactionId][msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "Owners required");
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _owners.length, "Invalid number of required confirmations");

        owners = _owners;
        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address to, uint256 value) public onlyOwner {
        uint256 transactionId = transactionCount;

        transactions[transactionId] = Transaction({
            to: to,
            value: value,
            executed: false
        });

        transactionCount++;

        emit Submit(transactionId, to, value);
        confirmTransaction(transactionId);
    }

    function confirmTransaction(uint256 transactionId) public onlyOwner txExists(transactionId) notConfirmed(transactionId) notExecuted(transactionId) {
        confirmations[transactionId][msg.sender] = true;
        emit Confirm(transactionId);

        executeTransaction(transactionId);
    }

    function executeTransaction(uint256 transactionId) public onlyOwner txExists(transactionId) notExecuted(transactionId) {
        require(getConfirmationCount(transactionId) >= requiredConfirmations, "Not enough confirmations");

        Transaction storage txn = transactions[transactionId];
        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}("");
        require(success, "Transaction execution failed");

        emit Execute(transactionId);
    }

    function getConfirmationCount(uint256 transactionId) public view returns (uint256 count) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count += 1;
            }
        }
    }

    function isOwner(address account) public view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == account) {
                return true;
            }
        }
        return false;
    }

    function revokeConfirmation(uint256 transactionId) public onlyOwner txExists(transactionId) notExecuted(transactionId) {
        require(confirmations[transactionId][msg.sender], "Transaction not confirmed");

        confirmations[transactionId][msg.sender] = false;
        emit Revoke(transactionId, msg.sender);
    }
}

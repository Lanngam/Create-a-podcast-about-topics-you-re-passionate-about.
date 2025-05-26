// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract DecentralizedPodcastPlatform {
    
    // Struct to represent a podcast
    struct Podcast {
        uint256 id;
        string title;
        string description;
        string ipfsHash; // IPFS hash for audio file
        address creator;
        uint256 subscriptionPrice; // Price in wei for premium content
        uint256 createdAt;
        bool isActive;
    }
    
    // Struct to represent a subscription
    struct Subscription {
        address subscriber;
        uint256 podcastId;
        uint256 expiresAt;
        bool isActive;
    }
    
    // State variables
    uint256 public nextPodcastId;
    uint256 public platformFee = 250; // 2.5% platform fee (basis points)
    address public owner;
    
    // Mappings
    mapping(uint256 => Podcast) public podcasts;
    mapping(address => uint256[]) public creatorPodcasts;
    mapping(uint256 => mapping(address => Subscription)) public subscriptions;
    mapping(address => uint256) public creatorBalances;
    
    // Events
    event PodcastCreated(
        uint256 indexed podcastId,
        address indexed creator,
        string title,
        uint256 subscriptionPrice
    );
    
    event SubscriptionPurchased(
        uint256 indexed podcastId,
        address indexed subscriber,
        uint256 duration,
        uint256 amount
    );
    
    event CreatorPayout(
        address indexed creator,
        uint256 amount
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier podcastExists(uint256 _podcastId) {
        require(_podcastId < nextPodcastId, "Podcast does not exist");
        _;
    }
    
    modifier onlyCreator(uint256 _podcastId) {
        require(podcasts[_podcastId].creator == msg.sender, "Only creator can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        nextPodcastId = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new podcast
     * @param _title Title of the podcast
     * @param _description Description of the podcast
     * @param _ipfsHash IPFS hash of the audio file
     * @param _subscriptionPrice Price for premium subscription (0 for free)
     */
    function createPodcast(
        string memory _title,
        string memory _description,
        string memory _ipfsHash,
        uint256 _subscriptionPrice
    ) external {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        
        uint256 podcastId = nextPodcastId;
        
        podcasts[podcastId] = Podcast({
            id: podcastId,
            title: _title,
            description: _description,
            ipfsHash: _ipfsHash,
            creator: msg.sender,
            subscriptionPrice: _subscriptionPrice,
            createdAt: block.timestamp,
            isActive: true
        });
        
        creatorPodcasts[msg.sender].push(podcastId);
        nextPodcastId++;
        
        emit PodcastCreated(podcastId, msg.sender, _title, _subscriptionPrice);
    }
    
    /**
     * @dev Core Function 2: Subscribe to a podcast (for premium content)
     * @param _podcastId ID of the podcast to subscribe to
     * @param _duration Duration of subscription in seconds
     */
    function subscribeToPodcast(uint256 _podcastId, uint256 _duration) 
        external 
        payable 
        podcastExists(_podcastId) 
    {
        Podcast storage podcast = podcasts[_podcastId];
        require(podcast.isActive, "Podcast is not active");
        require(podcast.subscriptionPrice > 0, "This is a free podcast");
        
        uint256 totalCost = (podcast.subscriptionPrice * _duration) / 86400; // Price per day
        require(msg.value >= totalCost, "Insufficient payment");
        
        // Calculate platform fee and creator payout
        uint256 platformFeeAmount = (totalCost * platformFee) / 10000;
        uint256 creatorPayout = totalCost - platformFeeAmount;
        
        // Update creator balance
        creatorBalances[podcast.creator] += creatorPayout;
        
        // Create or update subscription
        uint256 currentExpiry = subscriptions[_podcastId][msg.sender].expiresAt;
        uint256 newExpiry = (currentExpiry > block.timestamp) ? 
            currentExpiry + _duration : 
            block.timestamp + _duration;
            
        subscriptions[_podcastId][msg.sender] = Subscription({
            subscriber: msg.sender,
            podcastId: _podcastId,
            expiresAt: newExpiry,
            isActive: true
        });
        
        // Refund excess payment
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
        
        emit SubscriptionPurchased(_podcastId, msg.sender, _duration, totalCost);
    }
    
    /**
     * @dev Core Function 3: Withdraw earnings for creators
     */
    function withdrawEarnings() external {
        uint256 balance = creatorBalances[msg.sender];
        require(balance > 0, "No earnings to withdraw");
        
        creatorBalances[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
        
        emit CreatorPayout(msg.sender, balance);
    }
    
    // View functions
    function getPodcast(uint256 _podcastId) 
        external 
        view 
        podcastExists(_podcastId) 
        returns (Podcast memory) 
    {
        return podcasts[_podcastId];
    }
    
    function hasActiveSubscription(uint256 _podcastId, address _subscriber) 
        external 
        view 
        returns (bool) 
    {
        return subscriptions[_podcastId][_subscriber].expiresAt > block.timestamp &&
               subscriptions[_podcastId][_subscriber].isActive;
    }
    
    function getCreatorPodcasts(address _creator) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return creatorPodcasts[_creator];
    }
    
    function getCreatorBalance(address _creator) 
        external 
        view 
        returns (uint256) 
    {
        return creatorBalances[_creator];
    }
    
    // Admin functions
    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Fee cannot exceed 10%");
        platformFee = _newFee;
    }
    
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner).transfer(balance);
    }
    
    function deactivatePodcast(uint256 _podcastId) 
        external 
        podcastExists(_podcastId) 
        onlyCreator(_podcastId) 
    {
        podcasts[_podcastId].isActive = false;
    }
}

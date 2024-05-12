// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    /* Events */
    // Must be redefined, can't be imported
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // Run only on anvil
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        // On any Raffle contract, get the OPEN value for the RaffleState enum/type
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    ///////////////////
    /** Enter Raffle */
    ///////////////////
    function testRaffleRevertsNotEnoughPaid() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsEnteredPlayer() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);

        // expectEmit(topic1, topic2, topic3, checkData, address emitter), topic0 is always checked
        vm.expectEmit(true, false, false, false, address(raffle));

        // Emit the event we expect to see
        emit EnteredRaffle(PLAYER);

        // Where the emit is suppose to happen
        raffle.enterRaffle{value: entranceFee}();
    }

    function testEntryDisabledWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Set block time and number, +1 sanity
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Expect revert on the next TX
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    ///////////////////
    /** checkUpkeep */
    ///////////////////
    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Should return false
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimePassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(upkeepNeeded);
    }

    /////////////////////
    /** performUpkeep */
    /////////////////////
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // No expect not revert, considered a pass if it runs
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        // Custom error with parameters
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    // For testing using the output of an event/requestId
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory logEntries = vm.getRecordedLogs();
        bytes32 requestId = logEntries[1].topics[1]; // All logs in foundry are recorded in byte32

        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    ////////////////////////
    /** fufillRandomWords */
    ////////////////////////
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE); // prank + deal
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        // Get requestId from logs
        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory logEntries = vm.getRecordedLogs();
        bytes32 requestId = logEntries[1].topics[1];

        uint256 previousTimestamp = raffle.getLastTimestamp();

        // Pretend to be chainlink vrf to get random number and pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        assert(uint256(raffle.getRaffleState()) == 0); // fulfillRandomWords should reset state
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getPlayerCount() == 0); // fulfillRandomWords should reset player count
        assert(raffle.getLastTimestamp() > previousTimestamp);
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE - entranceFee + prize
        );
    }
}

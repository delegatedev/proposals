// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./YAMHelper.sol";
import "./YAMDelegator.sol";

interface Vm {
    function warp(uint) external;
    function roll(uint) external;
    function store(address,bytes32,bytes32) external;
    function load(address,bytes32) external returns (bytes32);
}

interface Timelock {
    function admin() external returns (address);
    function delay() external returns (uint256);
}

interface YAMGovernorAlpha {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    function latestProposalIds(address proposer) external returns (uint256);

    function propose(
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256); 

    function queue(uint256 proposalId) external ;

    function execute(uint256 proposalId) external payable;

    function castVote(uint256 proposalId, bool support) external;

    function state(uint256 proposalId) external view returns (ProposalState);
    function getPriorVotes(address account, uint256 blockNumber) external returns (uint256);
}

interface YAMReserves {}


contract YAMTest is DSTest {
    bytes20 constant CHEAT_CODE = bytes20(uint160(uint(keccak256('hevm cheat code'))));
    Timelock internal timelock = Timelock(0x8b4f1616751117C38a0f84F9A146cca191ea3EC5);
    YAMReserves internal reserves = YAMReserves(0x97990B693835da58A281636296D2Bf02787DEa17);
    YAMDelegator internal yamDelegator = YAMDelegator(0x0AaCfbeC6a24756c20D41914F2caba817C0d8521);
    address internal constant yUSDC = address(0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9);
    address internal constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address internal proposer;
    YAMHelper internal yamHelper;
    Vm internal vm;

    function setUpYAMTest() internal {
        vm = Vm(address(CHEAT_CODE));
        proposer = address(this);
        yamHelper = new YAMHelper();
        yamHelper.addKnown(address(yamDelegator), "pendingGov()", 4);
        yamHelper.addKnown(address(yamDelegator), "totalSupply()", 8);
        yamHelper.addKnown(address(yamDelegator), "balanceOfUnderlying(address)", 10);
        yamHelper.addKnown(address(yamDelegator), "initSupply()", 12);
        yamHelper.addKnown(address(yamDelegator), "checkpoints(address,uint32)", 15);
        yamHelper.addKnown(address(yamDelegator), "numCheckpoints(address)", 16);
        // 0 out balance
        yamHelper.writeBoU(yamDelegator, proposer, 0);
    }

    function rollProposal(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    )
        internal
    {
        YAMGovernorAlpha gov = YAMGovernorAlpha(timelock.admin());

        gov.propose(
            targets,
            values,
            signatures,
            calldatas,
            description
        );

        uint256 id = gov.latestProposalIds(proposer);

        voteOnLatestProposal();

        vm.roll(block.number +  12345);

        YAMGovernorAlpha.ProposalState state = gov.state(id);

        assertTrue(state == YAMGovernorAlpha.ProposalState.Succeeded);

        gov.queue(id);

        vm.warp(block.timestamp + timelock.delay());

        gov.execute(id);
    }

    function voteOnLatestProposal() public {
        vm.roll(block.number + 10);
        YAMGovernorAlpha gov = YAMGovernorAlpha(timelock.admin());
        uint256 id = gov.latestProposalIds(proposer);
        gov.castVote(id, true);
    }
}

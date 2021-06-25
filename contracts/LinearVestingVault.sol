// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LinearVestingVault
 * @dev A token vesting contract that will release tokens gradually like a standard
 * equity vesting schedule, with a cliff and vesting period but no arbitrary restrictions
 * on the frequency of claims. Optionally has an initial tranche claimable immediately
 * after the cliff expires.
 */
contract LinearVestingVault is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    event Issued(
        address beneficiary,
        uint256 amount,
        uint256 start,
        uint256 cliff,
        uint256 duration
    );

    event Released(address beneficiary, uint256 amount, uint256 remaining);
    event Revoked(address beneficiary, uint256 allocationAmount, uint256 revokedAmount);

    struct Allocation {
        uint256 start;
        uint256 cliff;
        uint256 duration;
        uint256 total;
        uint256 claimed;
        uint256 initial;
    }

    ERC20 public token;
    mapping(address => Allocation[]) public allocations;

    /**
     * @dev Creates a vesting contract that releases allocations of an ERC20 token over time.
     * @param _token ERC20 token to be vested
     */
    constructor(ERC20 _token) {
        token = _token;
    }

    /**
     * @dev Creates a new allocation for a beneficiary. Tokens are released linearly over
     * time until a given number of seconds have passed since the start of the vesting
     * schedule.
     * @param _beneficiary address to which tokens will be released
     * @param _amount uint256 amount of the allocation (in wei)
     * @param _startAt uint256 the unix timestamp at which the vesting may begin
     * @param _cliff uint256 the number of seconds after _startAt before which no vesting occurs
     * @param _duration uint256 the number of seconds after which the entire allocation is vested
     * @param _initialPct uint256 percentage of the allocation initially available (integer, 0-100)
     */
    function issue(
        address _beneficiary,
        uint256 _amount,
        uint256 _startAt,
        uint256 _cliff,
        uint256 _duration,
        uint256 _initialPct
    ) public onlyOwner {
        require(token.allowance(msg.sender, address(this)) >= _amount, "Token allowance not sufficient");
        require(_beneficiary != address(0), "Cannot grant tokens to the zero address");
        require(_cliff <= _duration, "Cliff must not exceed duration");
        require(_initialPct <= 100, "Initial release percentage must be an integer 0 to 100 (inclusive)");

        token.safeTransferFrom(msg.sender, address(this), _amount);
        allocations[_beneficiary].push(Allocation(_startAt, _cliff, _duration, _amount, 0, _amount.mul(_initialPct).div(100)));

        emit Issued(_beneficiary, _amount, _startAt, _cliff, _duration);
    }
    
    /**
     * @dev Revokes an existing allocation. Any vested tokens are transferred
     * to the beneficiary and the remainder are returned to the contract's owner.
     * @param _beneficiary The address whose allocation is to be revoked
     * @param _index The index of vesting array
     */
    function revoke(
        address _beneficiary, uint256 _index
    ) public onlyOwner {
        uint256 length = allocations[_beneficiary].length;
        require(_index < length, "Index should be smaller than vesting array length");
        Allocation memory allocation = allocations[_beneficiary][_index];
        
        uint256 total = allocation.total;
        uint256 remainder = total.sub(allocation.claimed);
        if (_index != length - 1) allocations[_beneficiary][_index] = allocations[_beneficiary][length - 1];
        allocations[_beneficiary].pop();
        
        token.safeTransfer(msg.sender, remainder);
        emit Revoked(
            _beneficiary,
            total,
            remainder
        );
    }

    /**
     * @dev Transfers vested tokens to a given beneficiary. Callable by anyone.
     * @param _beneficiary address which is being vested
     * @param _index The index of vesting array
     */
    function release(address _beneficiary, uint256 _index) public {
        require(_index < allocations[_beneficiary].length, "Index should be smaller than vesting array length");
        Allocation storage allocation = allocations[_beneficiary][_index];

        uint256 amount = _releasableAmount(allocation);
        require(amount > 0, "Nothing to release");
        
        allocation.claimed = allocation.claimed.add(amount);
        token.safeTransfer(_beneficiary, amount);
        emit Released(
            _beneficiary,
            amount,
            allocation.total.sub(allocation.claimed)
        );
    }
    
    /**
     * @dev Transfers vested tokens to a given beneficiary. Callable by anyone.
     * @param _beneficiary address which is being vested
     */
    function releaseAll(address _beneficiary) external {
        for (uint256 i = 0; i < allocations[_beneficiary].length; i++) {
            release(_beneficiary, i);
        }
    }
    
    /**
     * @dev Calculates the amount that has already vested but has not been
     * released yet for a given address.
     * @param _beneficiary Address to check
     * @param _index The index of vesting array
     */
    function releasableAmount(address _beneficiary, uint256 _index)
        external
        view
        returns (uint256)
    {
        Allocation memory allocation = allocations[_beneficiary][_index];
        return _releasableAmount(allocation);
    }

    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     * @param allocation Allocation to calculate against
     */
    function _releasableAmount(Allocation memory allocation)
        internal
        view
        returns (uint256)
    {
        return _vestedAmount(allocation).sub(allocation.claimed);
    }

    /**
     * @dev Calculates the amount that has already vested.
     * @param allocation Allocation to calculate against
     */
    function _vestedAmount(Allocation memory allocation)
        internal
        view
        returns (uint256 amount)
    {
        if (block.timestamp < allocation.start.add(allocation.cliff)) {
            amount = 0;
        } else if (block.timestamp >= allocation.start.add(allocation.duration)) {
            // if the entire duration has elapsed, everything is vested
            amount = allocation.total;
        } else {
            // the "initial" amount is available once the cliff expires, plus the
            // proportion of tokens vested as of the current block's timestamp
            amount = allocation.initial.add(
                allocation.total
                    .sub(allocation.initial)
                    .sub(amount)
                    .mul(block.timestamp.sub(allocation.start))
                    .div(allocation.duration)
            );
        }
        
        return amount;
    }
}
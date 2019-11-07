/**
 *Submitted for verification at Etherscan.io on 2018-09-17
*/

/// bite.sol -- Dai liquidation module

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.4.24;

/// note.sol -- the `note' modifier, for logging calls as events

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

contract DSNote {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  guy,
        bytes32  indexed  foo,
        bytes32  indexed  bar,
        uint              wad,
        bytes             fax
    ) anonymous;

    modifier note {
        bytes32 foo;
        bytes32 bar;

        assembly {
            foo := calldataload(4)
            bar := calldataload(36)
        }

        emit LogNote(msg.sig, msg.sender, foo, bar, msg.value, msg.data);

        _;
    }
}

contract Flippy {
    function kick(bytes32 urn, address gal, uint tab, uint lot, uint bid)
        public returns (uint);
    function gem() public returns (address);
}

contract Hopeful {
    function hope(address) public;
    function nope(address) public;
}

contract VatLike {
    function ilks(bytes32) public view returns (uint,uint,uint,uint);
    function urns(bytes32,bytes32) public view returns (uint,uint);
    function grab(bytes32,bytes32,bytes32,bytes32,int,int) public;
}

contract PitLike {
    function ilks(bytes32) public view returns (uint,uint);
}

contract VowLike {
    function fess(uint) public;
}

contract Cat is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address guy) public note auth { wards[guy] = 1; }
    function deny(address guy) public note auth { wards[guy] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    struct Ilk {
        address flip;  // Liquidator
        uint256 chop;  // Liquidation Penalty   [ray]
        uint256 lump;  // Liquidation Quantity  [wad]
    }
    struct Flip {
        bytes32 ilk;  // Collateral Type
        bytes32 urn;  // CDP Identifier
        uint256 ink;  // Collateral Quantity [wad]
        uint256 tab;  // Debt Outstanding    [wad]
    }

    mapping (bytes32 => Ilk)  public ilks;
    mapping (uint256 => Flip) public flips;
    uint256                   public nflip;

    uint256 public live;
    VatLike public vat;
    PitLike public pit;
    VowLike public vow;

    // --- Events ---
    event Bite(
      bytes32 indexed ilk,
      bytes32 indexed urn,
      uint256 ink,
      uint256 art,
      uint256 tab,
      uint256 flip,
      uint256 iArt
    );

    // --- Init ---
    constructor(address vat_) public {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        live = 1;
    }

    // --- Math ---
    uint constant ONE = 10 ** 27;

    function mul(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
        require(y == 0 || z / y == x);
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
        require(y == 0 || z / y == x);
        z = z / ONE;
    }

    // --- Administration ---
    function file(bytes32 what, address data) public note auth {
        if (what == "pit") pit = PitLike(data);
        if (what == "vow") vow = VowLike(data);
    }
    function file(bytes32 ilk, bytes32 what, uint data) public note auth {
        if (what == "chop") ilks[ilk].chop = data;
        if (what == "lump") ilks[ilk].lump = data;
    }
    function file(bytes32 ilk, bytes32 what, address flip) public note auth {
        if (what == "flip") ilks[ilk].flip = flip;
    }

    // --- CDP Liquidation ---
    function bite(bytes32 ilk, bytes32 urn) public returns (uint) {
        require(live == 1);
        (uint take, uint rate, uint Ink, uint Art) = vat.ilks(ilk); Art; Ink; take;
        (uint spot, uint line) = pit.ilks(ilk); line;
        (uint ink , uint art)  = vat.urns(ilk, urn);
        uint tab = rmul(art, rate);

        require(rmul(ink, spot) < tab);  // !safe

        vat.grab(ilk, urn, bytes32(address(this)), bytes32(address(vow)), -int(ink), -int(art));
        vow.fess(tab);

        flips[nflip] = Flip(ilk, urn, ink, tab);

        emit Bite(ilk, urn, ink, art, tab, nflip, Art);

        return nflip++;
    }
    function flip(uint n, uint wad) public note returns (uint id) {
        require(live == 1);
        Flip storage f = flips[n];
        Ilk  storage i = ilks[f.ilk];

        require(wad <= f.tab);
        require(wad == i.lump || (wad < i.lump && wad == f.tab));

        uint tab = f.tab;
        uint ink = mul(f.ink, wad) / tab;

        f.tab -= wad;
        f.ink -= ink;

        Hopeful(Flippy(i.flip).gem()).hope(i.flip);
        id = Flippy(i.flip).kick({ urn: f.urn
                                 , gal: vow
                                 , tab: rmul(wad, i.chop)
                                 , lot: ink
                                 , bid: 0
                                 });
        Hopeful(Flippy(i.flip).gem()).nope(i.flip);
    }
}
#[starknet::contract]
mod ERC404Factory {
    // Starknet deps
    use erc404::token::erc404::interface::ERC404ABIDispatcherTrait;
    use core::traits::Destruct;
    use erc404::token::erc404::ERC404ABIDispatcher;
    use starknet::ContractAddress;
    use starknet::{get_contract_address, get_caller_address, get_block_timestamp};
    use starknet::class_hash::ClassHash;
    use starknet::SyscallResultTrait;
    use poseidon::poseidon_hash_span;

    // External deps
    use array::ArrayTrait;
    use traits::{Into, TryInto};
    use zeroable::Zeroable;

    mod Errors {
        const ERROR_NOT_PROTOCOL_OWNER: felt252 = 'factory: not protocol owner';
        const ERROR_UNWHITELISTED_CLASS_HASH: felt252 = 'factory: unwlt class hash';
        const ERROR_INVALID_CLASS_HASH: felt252 = 'factory: invalid class hash';
    }

    #[derive(Drop, Serde)]
    struct DeployCallData {
        _protocol_owner: felt252,
        _id: felt252,
        _total_native_supply: felt252,
        _total_uris: felt252,
        _owner: felt252,
        _name: felt252,
        _symbol: felt252,
        _decimals: felt252,
        _base_uri_1: felt252,
        _base_uri_2: felt252,
        _base_uri_3: felt252,
        _base_uri_4: felt252,
        _base_uri_5: felt252,
    }

    #[storage]
    struct Storage {
        id: u256,
        protocol_owner: ContractAddress,
        collection_list: LegacyMap<ContractAddress, bool>,
        class_hash_allowed: LegacyMap<ClassHash, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        EventNewERC404Collection: EventNewERC404Collection,
        EventClassHashUpdated: EventClassHashUpdated,
        EventFactoryUpgraded: EventFactoryUpgraded
    }

    #[derive(Drop, starknet::Event)]
    struct EventNewERC404Collection {
        contract_address: ContractAddress,
        name: felt252,
        symbol: felt252,
        owner: ContractAddress,
        total_supply: u256,
        total_uris: u256,
        decimals: u8,
        base_uri_1: felt252,
        base_uri_2: felt252,
        base_uri_3: felt252,
        base_uri_4: felt252,
        base_uri_5: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct EventClassHashUpdated {
        class_hash: ClassHash,
        allowed: bool
    }

    #[derive(Drop, starknet::Event)]
    struct EventFactoryUpgraded {
        class_hash: ClassHash
    }

    #[constructor]
    fn constructor(ref self: ContractState, _protocol_owner: ContractAddress) {
        self.protocol_owner.write(_protocol_owner);
    }

    /////////////////
    // Read Method //
    /////////////////

    //////////////////
    // Write Method //
    //////////////////

    // classHash: Class hash của contract cần deploy
    // contractAddressSalt: Giá trị tùy ý
    // calldata: Constructor calldata
    // deployFromZero: Nếu false, địa chỉ người gọi hàm này sẽ là địa chỉ deploy contract mới
    #[external(v0)]
    fn deployERC404(
        ref self: ContractState,
        class_hash: ClassHash, // 0x057cae8f50740c2fe670b0c08e2533de4911384ce9ba8550ec0a797146249010
        total_native_supply: felt252,
        total_uris: felt252,
        owner: felt252,
        name: felt252, // APE -> 4280389
        symbol: felt252, // APE -> 4280389
        decimals: felt252, // 18
        base_uri_1: felt252, // https:// -> 7526768903561293615
        base_uri_2: felt252, // grow-api. -> 1908260580071614474542
        base_uri_3: felt252, // memeland.com/ -> 8667259951919390433031851306287
        base_uri_4: felt252, // token/ -> 128021892001327
        base_uri_5: felt252, // metadata/ -> 2018005679213229924655
    ) -> ContractAddress {
        assert(self.class_hash_allowed.read(class_hash), Errors::ERROR_UNWHITELISTED_CLASS_HASH);

        let mut hash_data: Array<felt252> = ArrayTrait::new();
        let mut calldata = array![];
        let deploy_data = DeployCallData {
            _protocol_owner: self.protocol_owner.read().into(),
            _id: (self.id.read() + 1).try_into().unwrap(),
            _total_native_supply: total_native_supply,
            _total_uris: total_uris,
            _owner: owner,
            _name: name,
            _symbol: symbol,
            _decimals: decimals,
            _base_uri_1: base_uri_1,
            _base_uri_2: base_uri_2,
            _base_uri_3: base_uri_3,
            _base_uri_4: base_uri_4,
            _base_uri_5: base_uri_5
        };
        Serde::serialize(@deploy_data, ref hash_data);
        let salt = poseidon_hash_span(hash_data.span());
        Serde::serialize(@deploy_data, ref calldata);

        self.id.write(self.id.read() + 1);

        let deployFromZero: bool = false;
        let (contract_address, _) = starknet::deploy_syscall(
            class_hash, salt, calldata.span(), deployFromZero
        )
            .unwrap();

        self.collection_list.write(contract_address, true);

        self
            .emit(
                EventNewERC404Collection {
                    contract_address: contract_address,
                    name: name,
                    symbol: symbol,
                    owner: owner.try_into().unwrap(),
                    total_supply: total_native_supply.into(),
                    total_uris: total_uris.into(),
                    decimals: decimals.try_into().unwrap(),
                    base_uri_1: base_uri_1,
                    base_uri_2: base_uri_2,
                    base_uri_3: base_uri_3,
                    base_uri_4: base_uri_4,
                    base_uri_5: base_uri_5,
                }
            );

        contract_address
    }

    #[external(v0)]
    fn set_class_hash_allowed(ref self: ContractState, class_hash: ClassHash, allowed: bool) {
        let caller = get_caller_address();
        assert(caller == self.protocol_owner.read(), Errors::ERROR_NOT_PROTOCOL_OWNER);

        self.class_hash_allowed.write(class_hash, allowed);

        self.emit(EventClassHashUpdated { class_hash: class_hash, allowed: allowed });
    }

    #[external(v0)]
    fn check_collection_info(
        self: @ContractState, potential_owner: ContractAddress, collection: ContractAddress
    ) -> bool {
        // Check collection valid
        if (!self.collection_list.read(collection)) {
            return false;
        }

        // Check potential owner is indeed the owner of collection
        let collection_owner = ERC404ABIDispatcher { contract_address: collection }.owner();

        if (potential_owner != collection_owner) {
            return false;
        }

        true
    }

    #[external(v0)]
    fn check_collection_address(self: @ContractState, collection: ContractAddress) -> bool {
        if (self.collection_list.read(collection)) {
            return true;
        }

        false
    }

    #[external(v0)]
    fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
        /// Check owner
        let caller = get_caller_address();
        assert(caller == self.protocol_owner.read(), Errors::ERROR_NOT_PROTOCOL_OWNER);

        /// Check class hash
        assert(!new_class_hash.is_zero(), Errors::ERROR_INVALID_CLASS_HASH);

        /// Upgrade
        starknet::replace_class_syscall(new_class_hash).unwrap_syscall();
        self.emit(EventFactoryUpgraded { class_hash: new_class_hash });
    }
}

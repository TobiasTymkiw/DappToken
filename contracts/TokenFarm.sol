// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DappToken.sol";
import "./LPToken.sol";

/**
 * @title Proportional Token Farm
 * @notice Una granja de staking donde las recompensas se distribuyen proporcionalmente al total stakeado.
 */
contract TokenFarm {
    //
    // Variables de estado
    //
    string public constant name = "Proportional Token Farm";
    address public immutable owner;
    DappToken public immutable dappToken;
    LPToken public immutable lpToken;

    uint256 public REWARD_PER_BLOCK; // Recompensa por bloque (total para todos los usuarios)
    //Bonus 4: Rango minimo y maximo de recompensa por bloque.
    uint256 public constant MIN_REWARD_PER_BLOCK = 1e17; // 0.1 token
    uint256 public constant MAX_REWARD_PER_BLOCK = 5e18; // 5 tokens
    uint256 public constant precision = 1e18; // Para evitar problemas de precisión con enteros
    uint256 public totalStakingBalance; // Total de tokens en staking
    //Bonus 5: Fees de withdraw.
    // Comisión por retiro (en porcentaje, ej: 2 significa 2%)
    uint256 public constant withdrawFeePercent = 2e16;
    address public immutable feeReceiver;

    // Eventos
    // Agregar eventos para Deposit, Withdraw, RewardsClaimed y RewardsDistributed.
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsDistributed(string message);
    event RewardPerBlockUpdated(uint256 oldReward, uint256 newReward);

    //Bonus 1: Modifiers.
    //Modifier OnlyOwner: Verifica que la función sea llamada por el owner del contrato.
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    //Modifier isStaking: Verifica que el usuario esté actualmente en staking.
    modifier isStaking() {
        require(
            stakersInfo[msg.sender].isStaking,
            "You are not currently staking"
        );
        _;
    }
    //Bonus 2: Estructura para almacenar la informacion de los usuarios en staking.
    struct StructUser {
        uint256 stakingBalance;
        uint256 checkpoint;
        uint256 pendingRewards;
        bool hasStaked;
        bool isStaking;
    }
    address[] public stakers;
    mapping(address => StructUser) public stakersInfo;

    // Constructor
    constructor(DappToken _dappToken, LPToken _lpToken) {
        // Configurar las instancias de los contratos de DappToken y LPToken.
        dappToken = _dappToken;
        lpToken = _lpToken;
        // Configurar al owner del contrato como el creador de este contrato.
        owner = msg.sender;
        //feeReceiver address
        feeReceiver = msg.sender; // El owner también recibe las comisiones de retiro
        //Inicializar REWARD_PER_BLOCK con 1e18 (1 token total por bloque).
        REWARD_PER_BLOCK = 1e18; // 1 token total por bloque
    }

    /**
     * @notice Deposita tokens LP para staking.
     * @param _amount Cantidad de tokens LP a depositar.
     */
    function deposit(uint256 _amount) external {
        // Verificar que amount sea mayor a 0.
        require(_amount > 0, "Amount must be greater than 0");
        StructUser storage user = stakersInfo[msg.sender];

        // Incrementar totalStakingBalance con amount.
        totalStakingBalance += _amount;
        // Si el usuario nunca ha hecho staking antes, agregarlo al array stakers y marcar hasStaked como true.
        if (!user.hasStaked) {
            stakers.push(msg.sender);
            user.hasStaked = true;
        }
        // Actualizar isStaking del usuario a true.
        user.isStaking = true;
        // Si checkpoints del usuario está vacío, inicializarlo con el número de bloque actual.
        if (user.checkpoint == 0) {
            user.checkpoint = block.number;
        }
        // Llamar a distributeRewards para calcular y actualizar las recompensas pendientes.
        if (user.pendingRewards > 0) {
            // Si el usuario ya tiene recompensas pendientes, distribuirlas antes de actualizar el balance.
            distributeRewards(msg.sender);
        }
        // Actualizar el balance de staking del usuario en stakingBalance.
        user.stakingBalance += _amount;
        // Emitir un evento de depósito.
        emit Deposit(msg.sender, _amount);
        // Transferir tokens LP del usuario a este contrato.
        require(
            lpToken.transferFrom(msg.sender, address(this), _amount),
            "token transfer from sender failed"
        );
    }

    /**
     * @notice Retira todos los tokens LP en staking.
     */
    function withdraw() external isStaking {
        StructUser storage user = stakersInfo[msg.sender];
        // Obtener el balance de staking del usuario.
        uint256 balance = user.stakingBalance;
        // Verificar que el balance de staking sea mayor a 0.
        require(balance > 0, "No balance to withdraw");

        //Actualiza los datos del usuario:
        // Restablecer stakingBalance del usuario a 0.
        user.stakingBalance = 0;
        // Reducir totalStakingBalance en el balance que se está retirando.
        totalStakingBalance -= balance;
        // Actualizar isStaking del usuario a false.
        user.isStaking = false;
        // Llamar a distributeRewards para calcular y actualizar las recompensas pendientes antes de restablecer el balance.
        distributeRewards(msg.sender);

        // Emitir un evento de retiro.
        emit Withdraw(msg.sender, balance);
        // Transferir los tokens LP de vuelta al usuario.
        require(
            lpToken.transfer(msg.sender, balance),
            "token transfer to sender failed"
        );
    }

    /**
     * @notice Reclama recompensas pendientes.
     */
    function claimRewards() external {
        StructUser storage user = stakersInfo[msg.sender];
        // Obtener el monto de recompensas pendientes del usuario desde pendingRewards.
        uint256 pendingAmount = user.pendingRewards;
        // Verificar que el monto de recompensas pendientes sea mayor a 0.
        require(pendingAmount > 0, "No rewards to claim");
        // Restablecer las recompensas pendientes del usuario a 0.
        user.pendingRewards = 0;
        uint256 feeAmount = ((pendingAmount * precision) * withdrawFeePercent) /
            precision;
        uint256 netAmount = (pendingAmount * precision) - feeAmount;

        // Emitir un evento de reclamo de recompensas.
        emit RewardsClaimed(msg.sender, netAmount);
        // Llamar a la función de acuñación (mint) en el contrato DappToken para transferir las recompensas al usuario.
        dappToken.mint(msg.sender, netAmount);
        if (feeAmount > 0 && feeReceiver != address(0)) {
            dappToken.mint(feeReceiver, feeAmount);
        }
    }

    /**
     * @notice Distribuye recompensas a todos los usuarios en staking.
     */
    function distributeRewardsAll() external onlyOwner {
        // Iterar sobre todos los usuarios en staking almacenados en el array stakers.
        uint256 stakersCount = stakers.length;
        for (uint256 i = 0; i < stakersCount; i++) {
            address beneficiary = stakers[i];
            StructUser storage user = stakersInfo[beneficiary];
            // Verificar que el usuario está haciendo staking.
            if (user.isStaking) {
                // Llamar a distributeRewards para calcular y actualizar las recompensas pendientes.
                // Para cada usuario, si están haciendo staking (isStaking == true), llamar a distributeRewards.
                distributeRewards(beneficiary);
            }
        }
        // Emitir un evento indicando que las recompensas han sido distribuidas.
        emit RewardsDistributed("Rewards distributed to all stakers");
    }

    /**
     * @notice Calcula y distribuye las recompensas proporcionalmente al staking total.
     * @dev La función toma en cuenta el porcentaje de tokens que cada usuario tiene en staking con respecto
     *      al total de tokens en staking (`totalStakingBalance`).
     *
     * Funcionamiento:
     * 1. Se calcula la cantidad de bloques transcurridos desde el último checkpoint del usuario.
     * 2. Se calcula la participación proporcional del usuario:
     *    share = stakingBalance[beneficiary] / totalStakingBalance
     * 3. Las recompensas para el usuario se determinan multiplicando su participación proporcional
     *    por las recompensas por bloque (`REWARD_PER_BLOCK`) y los bloques transcurridos:
     *    reward = REWARD_PER_BLOCK * blocksPassed * share
     * 4. Se acumulan las recompensas calculadas en `pendingRewards[beneficiary]`.
     * 5. Se actualiza el checkpoint del usuario al bloque actual.
     *
     * Ejemplo Práctico:
     * - Supongamos que:
     *    Usuario A ha stakeado 100 tokens.
     *    Usuario B ha stakeado 300 tokens.
     *    Total de staking (`totalStakingBalance`) = 400 tokens.
     *    `REWARD_PER_BLOCK` = 1e18 (1 token total por bloque).
     *    Han transcurrido 10 bloques desde el último checkpoint.
     *
     * Cálculo:
     * - Participación de Usuario A:
     *   shareA = 100 / 400 = 0.25 (25%)
     *   rewardA = 1e18 * 10 * 0.25 = 2.5e18 (2.5 tokens).
     *
     * - Participación de Usuario B:
     *   shareB = 300 / 400 = 0.75 (75%)
     *   rewardB = 1e18 * 10 * 0.75 = 7.5e18 (7.5 tokens).
     *
     * Resultado:
     * - Usuario A acumula 2.5e18 en `pendingRewards`.
     * - Usuario B acumula 7.5e18 en `pendingRewards`.
     *
     * Nota:
     * Este sistema asegura que las recompensas se distribuyan proporcionalmente y de manera justa
     * entre todos los usuarios en función de su contribución al staking total.
     */
    function distributeRewards(address beneficiary) private {
        // Obtener el último checkpoint del usuario desde checkpoints.
        StructUser storage user = stakersInfo[beneficiary];
        uint256 lastCheckpoint = user.checkpoint;
        // Verificar que el número de bloque actual sea mayor al checkpoint y que totalStakingBalance sea mayor a 0.
        require(
            block.number > lastCheckpoint,
            "No new blocks since last checkpoint"
        );
        require(
            totalStakingBalance > 0,
            "No staking balance to distribute rewards"
        );
        // Calcular la cantidad de bloques transcurridos desde el último checkpoint.
        uint256 blocksPassed = block.number - lastCheckpoint;
        // Actualizar el checkpoint del usuario al bloque actual.
        user.checkpoint = block.number;
        // Calcular la proporción del staking del usuario en relación al total staking (stakingBalance[beneficiary] / totalStakingBalance).
        // Calcular las recompensas del usuario multiplicando la proporción por REWARD_PER_BLOCK y los bloques transcurridos.
        // Participación proporcional (usando fracciones enteras)
        // Recompensa = recompensa por bloque * bloques * participación
        uint256 reward = (user.stakingBalance *
            REWARD_PER_BLOCK *
            blocksPassed) /
            totalStakingBalance /
            precision; // Usar 1e18 para evitar problemas de precisión con enteros
        // Actualizar las recompensas pendientes del usuario en pendingRewards.
        user.pendingRewards += reward;
    }

    /**
     * @notice Actualiza la recompensa por bloque.
     * @param _newReward Nueva recompensa por bloque.
     */
    function setRewardPerBlock(uint256 _newReward) external onlyOwner {
        require(_newReward >= MIN_REWARD_PER_BLOCK, "Below minimum reward");
        require(_newReward <= MAX_REWARD_PER_BLOCK, "Above maximum reward");
        // Emitir un evento antes de actualizar la recompensa.
        emit RewardPerBlockUpdated(REWARD_PER_BLOCK, _newReward);
        // Actualizar REWARD_PER_BLOCK con el nuevo valor.
        REWARD_PER_BLOCK = _newReward;
    }
}

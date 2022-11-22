
# Smart Contract Marmottoshis

Document visant à décrire le smart contract du projet Marmottoshis. Ce répertoire contient le code du contrat "MarmottoshisIsERC1155.sol". 

Vous pouvez retrouver le projet sur Twitter : https://twitter.com/Marmottoshis.
Si vous avez des questions, vous pouvez retrouver l'équipe et la communauté sur le Discord suivant : https://discord.gg/thecryptomasks dans le channel #Marmottoshis

Tous les liens utiles sont ici : https://linktr.ee/Marmottoshis

## Disclaimer
Les prix en Ethers sur le contrat ne **SONT PAS** les prix qui seront mis en place au déploiement, une communication arrivera à ce sujet plus tard.

Le contrat publié ici est **proche de sa version finale**. Cependant, la publication de ce code vise à démontrer en toute transparence ce qui sera mis en place, mais aussi à **détecter d'éventuelles anomalies** pouvant être présentes. Si vous trouvez un bug/une anomalie, n'hésitez pas à contacter le projet (ou @0xNekr/@DocMarmott sur Twitter).

Si vous êtes le premier à reporter un bug et qu'il est utile pour la suite du projet, vous serez bien sûr **récompensé**. 
 

Le contrat dans sa version définitive sera **disponible ici avant le déploiement** et **vérifié sur Etherscan** une fois déployé afin que vous puissiez vous assurer que rien n'a été modifié depuis la phase de "bug hunt" (ou que les corrections ont bien été faites).


## Features

**Pour l'utilisateur, ce contrat permet de :**

- Réserver son NFT avant le mint. 
- Mint son NFT sous forme de plusieurs phases (free mint - réservation mint - mint première whitelist - mint seconde whitelist - mint publique).
- Consulter combien de Satoshis sont présent sur le contrat.
- Consulter combien de Satoshis sont adossés à un ID de NFT spécifique.
- Brûler (burn) un NFT pour déclencher une demande de récupération des Satoshis. 

**Pour la "marmotte", ce contrat permet de :**

- Changer l'adresse de la marmotte actuelle.
- Ajouter des Satoshis sur le contrat.
- Retirer des Satoshis sur le contrat. (utile seulement en cas d'erreur, par exemple, un 0 de trop).

**Pour le propriétaire, ce contrat permet de :**

- Modifier l'étape de vente en cours. 
- Figer les métadonnées.
- Révéler les NFTs.
- Modifier l'URI des NFTs (pour révéler les métadonnées).
- Ajouter des artistes au contrat (pour les métadonnées on-chain).
- Modifier les routes de Merkle des whitelists.
- Modifier les différents prix.
- Récupérer les ETH du contrat.
- Changer de propriétaire.
## Fonctions importantes pour l'utilisateur

### Ajouter/Retirer du BTC

Lors d'un ajout ou un retrait de Satoshis sur le contrat, voici ce qu'il se passe : 

- Vérification que la personne qui souhaite ajouter/retirer des Satoshis est bien l'adresse "Marmott".
- Ajout/retrait du nombre de Satoshis à la balance du contrat.
- Récupérer le nombre d'ID contenant encore des NFTs afin de partager les Satoshis entre chaque. 
- Division du nombre de Satoshis par le nombre d'ID avec encore au moins 1 NFT. 
- Ajouter/retrait du résultat de cette division à la balance de chaque ID encore présent.

```solidity
function addBTC(uint satoshis) external {
    require(msg.sender == marmott, "Only Marmott can add BTC");
    balanceOfSatoshis = balanceOfSatoshis + satoshis;
    uint divedBy = getNumberOfIdLeft();
    require(divedBy > 0, "No NFT left");
    uint satoshisPerId = satoshis / divedBy;
    for (uint i = 1; i <= maxToken; i++) {
        if (supplyByID[i] > 0) {
            balanceOfSatoshiByID[i] = balanceOfSatoshiByID[i] + satoshisPerId;
        }
    }
}
```

```solidity
function subBTC(uint satoshis) external {
    require(msg.sender == marmott, "Only Marmott can sub BTC");
    balanceOfSatoshis = balanceOfSatoshis - satoshis;
    uint divedBy = getNumberOfIdLeft();
    require(divedBy > 0, "No NFT left");
    uint satoshisPerId = satoshis / divedBy;
    for (uint i = 1; i <= maxToken; i++) {
        if (supplyByID[i] > 0) {
            balanceOfSatoshiByID[i] = balanceOfSatoshiByID[i] - satoshisPerId;
        }
    }
}
````

### Brûler un BTC pour récupérer les Satoshis

Lorsque vous souhaitez récupérer vos Satoshis, vous allez interagir avec la fonction "burnAndRedeem" qui va brûler votre NFT afin d'émettre un événement (une demande de récupération) qui sera ensuite traité par la Marmotte. Tout ceci pourra se passer depuis le contrat, ou via la dApp. 

La fonction va simplement vérifier que votre NFT existe et que vous possédez bien un exemplaire.
Si c'est le cas, elle va brûler ce NFT, mettre à jour les balances de Satoshis (la balance totale et celle de votre ID de NFT) et les quantités de NFTs.
Pour finir, elle déclenche un événement avec votre adresse de transaction, l'ID que vous avez brûlé, le nombre (1), votre adresse Bitcoin renseignée, et le nombre de Satoshis que vous avez pu récupérer.

```solidity
function burnAndRedeem(uint _idToRedeem, string memory _btcAddress) public nonReentrant {
    require(_idToRedeem >= 1, "Nonexistent id");
    require(_idToRedeem <= maxToken, "Nonexistent id");
    require(balanceOf(msg.sender, _idToRedeem) >= 1, "Not enough Marmott to burn");
    _burn(msg.sender, _idToRedeem, 1);
    uint satoshisToRedeem = redeemableById(_idToRedeem);
    balanceOfSatoshis = balanceOfSatoshis - satoshisToRedeem;
    balanceOfSatoshiByID[_idToRedeem] = balanceOfSatoshiByID[_idToRedeem] - satoshisToRedeem;
    supplyByID[_idToRedeem] = supplyByID[_idToRedeem] - 1;
    emit newRedeemRequest(msg.sender, _idToRedeem, 1, _btcAddress, satoshisToRedeem);
}
```

### Réserver un mint

La réservation pour le mint vous permet de déposer un montant d'Ethers (la valeur de la réservation n'est pas encore définie) contre la certitude de pouvoir mint un NFT. 
Il faut absolument être dans la phase ouverte de réservation, envoyer assez d'Ethers, ne pas avoir déjà whitelist votre adresse et que le nombre de réservations total soit inférieur ou égal à 400.
Une fois ces conditions passées, votre adresse sera whitelist grâce à un tableau (adresse vers booléen). 

```solidity
function reservationForWhitelist() external payable nonReentrant {
    require(currentStep == Step.WLReservation, "Reservation for whitelist is not open");
    require(msg.value >= reservationPrice, "Not enought ether");
    require(reservationList[msg.sender] == false, "You are already in the pre-whitelist");
    require(currentReservationNumber + 1 <= 400, "Max pre-whitelist reached");
    currentReservationNumber = currentReservationNumber + 1;
    reservationList[msg.sender] = true;
}
```

### Mint

Il n'existe qu'une seule fonction unique pour mint. Elle gère elle-même toutes les phases. 
Pour pouvoir mint il faut être dans une des phases suivantes : "FreeMint", "ReservationMint", "FirstWhitelistMint", "SecondWhitelistMint", "PublicMint".
La fonction va vérifier que l'ID que vous cherchez à mint existe et que l'ID en question n'a pas atteint sa supply maximale.

Ensuite, en fonction de la phase, elle vérifiera, grâce à la preuve de Merkle (ou tableau de réservation), que vous avez le droit de mint durant la phase. 
Si vous avez le droit de mint, elle vérifiera que la supply max n'est pas atteinte pour votre phase (il y aura + de whitelist que de NFT disponibles en phase de "First" et "Second" whitelist).
Pour finir, elle vérifiera si vous avez envoyé assez d'Ethers et si vous n'avez pas déjà mint pendant la phase.

Si toutes les conditions sont passées, votre NFT sera mint et un événement sera déclenché.

```solidity
function mint(uint idToMint, bytes32[] calldata _proof) public payable nonReentrant {
    require(
        currentStep == Step.FreeMint ||
        currentStep == Step.ReservationMint ||
        currentStep == Step.FirstWhitelistMint ||
        currentStep == Step.SecondWhitelistMint ||
        currentStep == Step.PublicMint
    , "Sale is not open");
    require(idToMint >= 1, "Nonexistent id");
    require(idToMint <= maxToken, "Nonexistent id");
    require(supplyByID[idToMint] + 1 <= maxSupply, "Max supply exceeded for this id");

    if (currentStep == Step.FreeMint) {
        require(isOnList(msg.sender, _proof, 0), "Not on free mint list");
        require(totalSupply() + 1 <= 77, "Max free mint supply exceeded");
        require(freeMintByWallet[msg.sender] + 1 <= 1, "You already minted your free NFT");
        freeMintByWallet[msg.sender] += 1;
        _mint(msg.sender, idToMint, 1, "");
    } else if (currentStep == Step.ReservationMint) {
        require(reservationList[msg.sender], "Not on reservation list");
        require(msg.value >= reservationNFTPrice, "Not enought ether");
        require(totalSupply() + 1 <= 477, "Max reservation mint supply exceeded");
        require(reservationMintByWallet[msg.sender] + 1 <= 1, "You already minted your reserved NFT");
        reservationMintByWallet[msg.sender] += 1;
        _mint(msg.sender, idToMint, 1, "");
    } else if (currentStep == Step.FirstWhitelistMint) {
        require(isOnList(msg.sender, _proof, 1), "Not on first whitelist");
        require(msg.value >= whitelistPrice, "Not enought ether");
        require(totalSupply() + 1 <= 577, "Max first whitelist mint supply exceeded");
        require(firstWhitelistMintByWallet[msg.sender] + 1 <= 1, "You already minted your first whitelist NFT");
        firstWhitelistMintByWallet[msg.sender] += 1;
        _mint(msg.sender, idToMint, 1, "");
    } else if (currentStep == Step.SecondWhitelistMint) {
        require(isOnList(msg.sender, _proof, 2), "Not on second whitelist");
        require(msg.value >= whitelistPrice, "Not enought ether");
        require(totalSupply() + 1 <= 777, "Max second whitelist mint supply exceeded");
        require(secondWhitelistMintByWallet[msg.sender] + 1 <= 1, "You already minted your second whitelist NFT");
        secondWhitelistMintByWallet[msg.sender] += 1;
        _mint(msg.sender, idToMint, 1, "");
    } else {
        require(msg.value >= publicPrice, "Not enought ether");
        require(totalSupply() + 1 <= 777, "Max second whitelist mint supply exceeded");
        _mint(msg.sender, idToMint, 1, "");
    }
    supplyByID[idToMint]++;
    emit newMint(msg.sender, idToMint);
}
```

### Autres Fonctions

Les autres fonctions non listées ici permettent de consulter certaines informations, au propriétaire du contrat, de modifier certaines variables, etc...
Toutes les fonctions sont dans le contrat, il est conseillé de lire le contrat en entier, des commentaires sont présents pour vous aider à comprendre. 
## Auteur

- [@0xNekr](https://www.github.com/0xNekr)

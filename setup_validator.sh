#!/bin/bash

# Renkli çıktılar için tanımlar
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}RPCdot.com Vana DLP Validator Setup${NC}"

# Gereksinim kontrolü
echo -e "${GREEN}Gereksinimlerin kontrolü:${NC}"

command -v git >/dev/null 2>&1 || { echo >&2 "Git yüklü değil. Lütfen Git'i yükleyin ve tekrar deneyin."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo >&2 "Python 3.11+ yüklü değil. Lütfen Python'ı yükleyin."; exit 1; }
command -v poetry >/dev/null 2>&1 || { echo >&2 "Poetry yüklü değil. Lütfen Poetry'i yükleyin."; exit 1; }

echo -e "${GREEN}Gereksinimler karşılandı.${NC}"

# Vana DLP ChatGPT repo klonlama
echo -e "${GREEN}Vana DLP ChatGPT repo's download...${NC}"
git clone https://github.com/vana-com/vana-dlp-chatgpt.git
cd vana-dlp-chatgpt || exit

# .env dosyası oluşturma
echo -e "${GREEN}.env file creating...${NC}"
cp .env.example .env

# Bağımlılıkların yüklenmesi
echo -e "${GREEN}Python dowload...${NC}"
poetry install

# Vana CLI yükleme (isteğe bağlı)
read -p "Vana CLI download? (y/n): " cli_install
if [[ "$cli_install" == "y" ]]; then
    pip install vana
fi

# Cüzdan oluşturma
echo -e "${GREEN}Vana CLI ile cüzdan oluşturuluyor...${NC}"
vanacli wallet create --wallet.name default --wallet.hotkey default

echo -e "${GREEN}Cüzdan başarıyla oluşturuldu.${NC}"
echo "Lütfen mnemonic ifadeleri güvenli bir şekilde saklayın."

# Metamask için Satori Testnet kurulum bilgileri
echo -e "${GREEN}Satori Testnet bilgileri:${NC}"
echo -e "Ağ Adı: ${GREEN}Satori Testnet${NC}"
echo -e "RPC URL: ${GREEN}https://rpc.satori.vana.org${NC}"
echo -e "Zincir Kimliği: ${GREEN}14801${NC}"
echo -e "Para Birimi: ${GREEN}VANA${NC}"

# Özel anahtarları dışa aktarma ve MetaMask'e ekleme
echo -e "${GREEN}Özel anahtarlar dışa aktarılıyor...${NC}"
coldkey_private=$(vanacli wallet export_private_key | grep 'Your coldkey private key' | awk '{print $5}')
hotkey_private=$(vanacli wallet export_private_key | grep 'Your hotkey private key' | awk '{print $5}')

echo -e "${GREEN}Coldkey ve Hotkey özel anahtarlarınız:${NC}"
echo -e "Coldkey Özel Anahtar: ${GREEN}$coldkey_private${NC}"
echo -e "Hotkey Özel Anahtar: ${GREEN}$hotkey_private${NC}"

echo -e "${GREEN}Bu özel anahtarları MetaMask'e ekleyin.${NC}"
read -p "Devam etmek için Enter'a basın..."

# Testnet Faucet ile cüzdanları fonlama
echo -e "${GREEN}Cüzdanlarınızı Testnet VANA ile fonlayın: https://faucet.vana.org${NC}"
read -p "Cüzdanlarınız fonlandıktan sonra devam etmek için Enter'a basın..."

# DLP kurulum (isteğe bağlı)
read -p "Yeni bir DLP oluşturmak istiyor musunuz? (e/h): " create_dlp
if [[ "$create_dlp" == "e" ]]; then
    echo -e "${GREEN}DLP Smart Contract klonlanıyor...${NC}"
    cd .. || exit
    git clone https://github.com/vana-com/vana-dlp-smart-contracts.git
    cd vana-dlp-smart-contracts || exit
    yarn install

    echo -e "${GREEN}.env dosyası düzenleniyor...${NC}"
    echo "DEPLOYER_PRIVATE_KEY=$coldkey_private" >> .env
    echo "OWNER_ADDRESS=$(vanacli wallet print_wallets | grep 'Coldkey Address' | awk '{print $3}')" >> .env
    echo "SATORI_RPC_URL=https://rpc.satori.vana.org" >> .env
    read -p "DLP ismi: " dlp_name
    read -p "DLP token ismi: " token_name
    read -p "DLP token sembolü: " token_symbol
    echo "DLP_NAME=$dlp_name" >> .env
    echo "DLP_TOKEN_NAME=$token_name" >> .env
    echo "DLP_TOKEN_SYMBOL=$token_symbol" >> .env

    echo -e "${GREEN}DLP sözleşmesi dağıtılıyor...${NC}"
    npx hardhat deploy --network satori --tags DLPDeploy
else
    echo -e "${GREEN}Mevcut bir DLP'ye katılmak için gerekli bilgileri alın.${NC}"
fi

# Validatör olarak kayıt olma
echo -e "${GREEN}Validatör olarak kaydoluyorsunuz...${NC}"
./vanacli dlp register_validator --stake_amount 10

if [[ "$create_dlp" == "e" ]]; then
    echo -e "${GREEN}Validatör onayı yapılıyor...${NC}"
    ./vanacli dlp approve_validator --validator_address=$(vanacli wallet print_wallets | grep 'Hotkey Address' | awk '{print $3}')
fi

# Validatör node'u çalıştırma
echo -e "${GREEN}Validatör node'u başlatılıyor...${NC}"
poetry run python -m chatgpt.nodes.validator

echo -e "${GREEN}Kurulum tamamlandı. Validatör node'unuz çalışıyor.${NC}"

#!/data/data/com.termux/files/usr/bin/bash
# 0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣

# Github Manager
[[ -d ".git" ]] && rm -rf ".git"

#  Instalamos `gh` en Termux si no está instalado
if ! command -v gh &>/dev/null; then
    pkg update -y && pkg install gh -y
fi

pregunta_github() {
    while true; do
        echo -e "\n"
        echo -e "1️⃣ Registrarme a Github."
        echo -e "2️⃣ Crear token de GitHub?"
        echo -e "3️⃣ Ingresar desde termux (gh auth login)"
        echo -e "4️⃣ Proseguir a ingresar token (Recomendado)"
        echo -e "5️⃣ Salir"
        read -rp "👉 Elige una opción (1/2/3/4/5): " opcion

        case "$opcion" in
            1|01)
                sleep 1.5
                echo -e "Abriendo GitHub para para registrarse."
                termux-open-url "https://github.com/login"
                ;;
            2|02)
                echo -e "🔗 Abrir GitHub para para crear un token de:\nfichas clásicas con permisos para repo y workflow. O todos..."
                echo -n "Presiona cualquier tecla para continuar...";read -n 1
                # Crea un nuevo token fichas clásicas con permisos para repo y workflow. O todos.
                termux-open-url "https://github.com/settings/tokens"
                echo -n "✅ Una vez creado y copiado el token, presiona cualquier tecla para continuar...";read -n 1
                ;;
            3|03)
                gh auth login
                ;;
            4|04)
                break
                ;;
            5|05)
                echo "👋 Saliendo..."
                exit 1
                ;;
            *)
                echo "⚠️ Opción inválida. Intenta nuevamente."
                ;;
        esac
    done
}

# Archivo de configuración de GitHub CLI
CONFIG_FILE="$HOME/.config/gh/hosts.yml"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
ssh_token() {

    # Verificar autenticación via gh auth login
    echo "🔍 Verificando autenticación en GitHub..."
    if gh auth status &>/dev/null; then
        echo "✅ Ya estás autenticado en GitHub."
        return 1
    fi

    echo "⚠️ No estás autenticado. Iniciando sesión automática..."

    # Verificar si ya hay un token válido
    if [[ -f "$CONFIG_FILE" ]] && grep -q "oauth_token" "$CONFIG_FILE"; then
        TOKEN=$(grep "oauth_token" "$CONFIG_FILE" | awk '{print $2}')
        if curl -s -H "Authorization: token $TOKEN" https://api.github.com/user | grep -q "login"; then
            echo "✅ Token válido encontrado, autenticando..."
            return 0
        else
            echo "❌ Token inválido o expirado. Eliminando credenciales..."
            rm -f "$CONFIG_FILE" >/dev/null
            pregunta_github
        fi
    fi
    
    pregunta_github
    # Pedir token si no hay uno válido
    echo "🔑 Ingresa tu token de GitHub (PAT):"
    read -sp "Token: " TOKEN
    echo

    # Asegurar que la clave SSH existe
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        echo "⚠️ No se encontró una clave SSH. Creando una nueva..."
        # ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
        ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N "" -q
    fi

    # Agregar la clave SSH a GitHub automáticamente
    echo "✅ Subiendo clave SSH a GitHub..."
    SSH_KEY_CONTENT=$(cat "$SSH_KEY_PATH")
    curl -s -H "Authorization: token $TOKEN" \
         -X POST -d "{\"title\":\"$(hostname) SSH Key\",\"key\":\"$SSH_KEY_CONTENT\"}" \
         https://api.github.com/user/keys &> /dev/null

    # Guardar configuración en ~/.config/gh/hosts.yml
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
github.com:
    user: $(whoami)
    oauth_token: $TOKEN
    git_protocol: ssh
EOF

    echo "✅ Configuración guardada, autenticando..."

    # Agregar la clave SSH de GitHub a la lista de hosts conocidos automáticamente
    echo "🔑 Agregando GitHub a los hosts conocidos..."
    ssh-keyscan github.com >> "$KNOWN_HOSTS" 2>/dev/null

    # Verificar conexión clave SSH con GitHub
    echo "🔗 Verificando conexión SSH con GitHub..."
    ssh -o StrictHostKeyChecking=no -T git@github.com &> /dev/null

    # Verificar si la autenticación fue exitosa
    if gh auth status &>/dev/null; then
        echo "✅ Autenticación SSH completada con éxito."
        return 0
    else
        echo "❌ Fallo en la autenticación. Intenta manualmente con 'gh auth login'."
        exit 1
    fi
}

ssh_token

ssh -T git@github.com &>/dev/null
if [ $? -ne 1 ]; then
    # Asegurar que la clave SSH existe
    if [[ -f "$SSH_KEY_PATH" ]]; then

        # Agregar la clave SSH a GitHub automáticamente
        echo "✅ Subiendo clave SSH a GitHub..."
        SSH_KEY_CONTENT=$(cat "$SSH_KEY_PATH")
        curl -s -H "Authorization: token $TOKEN" \
             -X POST -d "{\"title\":\"$(hostname) SSH Key\",\"key\":\"$SSH_KEY_CONTENT\"}" \
             https://api.github.com/user/keys &> /dev/null

        # Guardar configuración en ~/.config/gh/hosts.yml
        mkdir -p "$(dirname "$CONFIG_FILE")"
        cat > "$CONFIG_FILE" <<EOF
github.com:
    user: $(whoami)
    oauth_token: $TOKEN
    git_protocol: ssh
EOF

        echo "✅ Configuración guardada, autenticando..."

        # Agregar la clave SSH de GitHub a la lista de hosts conocidos automáticamente
        echo "🔑 Agregando GitHub a los hosts conocidos..."
        ssh-keyscan github.com >> "$KNOWN_HOSTS" 2>/dev/null

        # Verificar conexión clave SSH con GitHub
        echo "🔗 Verificando conexión SSH con GitHub..."
        ssh -o StrictHostKeyChecking=no -T git@github.com &> /dev/null
        pregunta_github
    fi
fi

# 2️⃣ Obtener nombre de usuario de GitHub
usuario_autenticado=$(ssh -T git@github.com 2>&1 | sed -n 's/Hi \([^ ]*\)!.*/\1/p')
usuario_autenticado1=$(gh api user 2>/dev/null | jq -r .login)
if [[ -n "$usuario_autenticado" ]];then
    usuario_github="$usuario_autenticado"
elif [[ -n "$usuario_autenticado1" ]];then 
    usuario_github="$usuario_autenticado1"
fi

# 3️⃣ Bucle hasta que el usuario ingrese un nombre de repositorio o decida salir
# Función para validar respuestas
validar_respuesta() {
    local resp=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    [[ "$resp" =~ ^(y|yes|s|si)$ ]] && return 0 || return 1
}
# Función para crear un nuevo repositorio
crear_repositorio() {
    echo "📂 Creando repositorio '$repo_name' en GitHub..."
    gh repo create "$repo_name" --public &>/dev/null
    echo "✅ Repositorio '$repo_name' creado correctamente."
}
# Bucle hasta que el usuario ingrese un nombre de repositorio válido
while [[ -z "$repo_name" ]]; do
    echo -e "\n📂 Ingresa el nombre del repositorio (obligatorio) o presiona 'q' para salir:"
    read -r repo_name

    if [[ "$repo_name" == "q" || "$repo_name" == "Q" ]]; then
        echo "🚪 Saliendo..."
        exit 0
    elif [[ -z "$repo_name" ]]; then
        continue
    fi

    echo -e "\n🚀Verificando repositorio '$repo_name'..."
    if gh repo view "$repo_name" &>/dev/null; then
        echo "⚠️ El repositorio '$repo_name' ya existe en GitHub."
        echo -e "¿Deseas actualizar la fuente de archivos? (si/no)"
        read -r respuesta
        if validar_respuesta "$respuesta"; then
            echo "✅ Actualizando archivos en '$repo_name'..."
            break
        else
            repo_name=""
            continue
        fi
    else
        echo -e "¿Deseas crear '$repo_name' como nuevo repositorio? (si/no)"
        read -r respuesta
        if validar_respuesta "$respuesta"; then
            crear_repositorio
            break
        else
            repo_name=""
            continue
        fi
    fi
done

# 4️⃣ Función para subir archivos al repositorio
subir_github() {
   # 1️⃣ Detectar archivo comprimido automáticamente
    archivo_comprimido=$(ls | grep -E '\.(zip|tar\.gz|tar\.xz|tar\.bz2|7z|rar)$' | head -n 1)
    [[ -z "$archivo_comprimido" ]] && archivo_comprimido=$(ls | grep -E '\.(html|cpp|pdf|txt|py|sh)$' | head -n 1)
    # Asegurar que el README.md tenga un título
    if [ ! -f "README.md" ]; then
        printf '# %s\n%s\n' "JalisFamily" "Proyecto Github Manager" > README.md
    fi
    git init &>/dev/null
    git add . &>/dev/null
    git reset -- sube_github_v1.sh  # Quita el archivo que no quieres subir del commit
    git config --global user.name "${usuario_github}" &>/dev/null
    # git config --global user.email "robertj.mezaurueta@gmail.com"
    # Verificar si el repositorio remoto ya está configurado
    if git remote | grep -q "origin" 2>/dev/null; then
        git remote set-url origin git@github.com:${usuario_github}/${repo_name}.git &>/dev/null
    else
        git remote add origin git@github.com:${usuario_github}/${repo_name}.git &>/dev/null
    fi
    git commit -m "first commit" &>/dev/null  
    git branch -M main &>/dev/null
    git push --force origin main
}

echo "⬆️  Subiendo archivos al repositorio..."
subir_github

echo -e "✅ Repositorio completo en:\ngit clone https://github.com/${usuario_github}/${repo_name}"
if [[ -n "$archivo_comprimido" ]]; then
    # echo -e "✅ Archivo específico en:\nwget https://raw.githubusercontent.com/${usuario_github}/${repo_name}/main/${archivo_comprimido}"
    echo -e "✅ Archivo específico en:\nwget -O ${archivo_comprimido} https://raw.githubusercontent.com/${usuario_github}/${repo_name}/main/${archivo_comprimido}"
fi


: '
# Si deseas que gh almacene las credenciales en lugar de usar la variable de entorno, debes eliminar el token de la sesión actual antes de ejecutar gh auth login nuevamente:
bash
unset GH_TOKEN GITHUB_TOKEN
export GH_TOKEN=
export GITHUB_TOKEN=
rm -rf ~/.config/gh/hosts.yml >/dev/null
rm -rf ~/.ssh/* >/dev/null
gh auth logout >/dev/null
sed -i '/export GH_TOKEN/d' ~/.bashrc ~/.profile ~/.bash_profile >/dev/null
source ~/.bashrc  # Recarga la configuración >/dev/null

# Verifica que ya no existan 
env | grep GH_TOKEN
env | grep GITHUB_TOKEN

gh auth login
# Esto te permitirá iniciar sesión manualmente y almacenar las credenciales en el sistema, en lugar de depender de la variable de entorno.

# Desde la línea de comandos (GitHub CLI) puedes eliminar un repositorio específico 
# Si tienes instalada la GitHub CLI (gh), usa el siguiente comando:
gh repo delete RobertNissan/unzip-7z --confirm


# copiar algo de un texto 
cat ~/.ssh/id_rsa.pub | termux-clipboard-set

: '

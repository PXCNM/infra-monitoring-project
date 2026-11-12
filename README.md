# infra-monitoring-project
Состав проекта:

| Файл                               | Назначение                                        |
| ---------------------------------- | ------------------------------------------------- |
| `check_api.sh`                     | Проверка доступности API по URL                   |
| `analyze_logs.sh`                  | Генерация `access.log` и статистика по нему       |
| `docker-compose.yml`, `nginx.conf` | Сервисы `api` и `proxy`                           |
| `.github/workflows/ci.yml`         | Проверка синтаксиса и тест скрипта в Pull Request |

## Безопасная передача файлов на удалённый сервер
Условные значения:
- `deploy` - имя пользователя на сервере;
- `server.example.com` - адрес сервера;
- `/opt/monitoring` - каталог проекта на сервере;
- `~/.ssh/id_ed25519_deploy` - путь к ключу.

### 1. Генерация SSH-ключей
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_deploy -C "deploy-key"
```
- `-t ed25519`. Если сервер очень старый и не поддерживает ed25519, используйте `-t rsa -b 4096`;
- `-f` - путь к файлу ключа. Создаются два файла: приватный `id_ed25519_deploy` и публичный `id_ed25519_deploy.pub`;
- `-C` - комментарий, по которому ключ можно опознать в `authorized_keys`.
Права на приватный ключ должны быть строгими:
```bash
chmod 600 ~/.ssh/id_ed25519_deploy
```
### 2. Копирование публичного ключа на сервер

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_deploy.pub deploy@server.example.com
```
Команда один раз запросит пароль пользователя и допишет публичный ключ в `~/.ssh/authorized_keys` на сервере с правильными правами. Если SSH работает не на 22 порту, добавьте `-p`.
Проверка входа по ключу:
```bash
ssh -i ~/.ssh/id_ed25519_deploy deploy@server.example.com "echo OK"
```
После того, как вход по ключу заработал, на сервере желательно отключить вход по паролю: в `/etc/ssh/sshd_config` задайте `PasswordAuthentication no` и перезапустите `sshd`.
### 3. Передача проекта
Исключайте из передачи служебные и сгенерированные файлы (`.git`, `access.log`).

**Вариант A. Архив + `scp`**
```bash
# локально: собрать архив
tar czf monitoring.tar.gz --exclude=.git --exclude=access.log .

# передать на сервер
scp -i ~/.ssh/id_ed25519_deploy monitoring.tar.gz deploy@server.example.com:/tmp/

# на сервере: распаковать
ssh -i ~/.ssh/id_ed25519_deploy deploy@server.example.com \
  "mkdir -p /opt/monitoring && tar xzf /tmp/monitoring.tar.gz -C /opt/monitoring && rm /tmp/monitoring.tar.gz"
```
Порт у `scp` задаётся заглавной `-P` (у `ssh` - строчной `-p`).

**Вариант B. `tar` + `ssh` одним потоком (без промежуточного файла)**
```bash
tar czf - --exclude=.git --exclude=access.log . | \
  ssh -i ~/.ssh/id_ed25519_deploy deploy@server.example.com \
  "mkdir -p /opt/monitoring && tar xzf - -C /opt/monitoring"
```
Данные шифруются SSH-каналом, на диске не остаётся временных архивов. 
## Пример деплоя
Полный цикл: передать файлы, запустить сервисы, проверить ответ.
```bash
KEY=~/.ssh/id_ed25519_deploy
HOST=deploy@server.example.com
DIR=/opt/monitoring

# 1. передать проект
tar czf - --exclude=.git --exclude=access.log . | \
  ssh -i "$KEY" "$HOST" "mkdir -p $DIR && tar xzf - -C $DIR"

# 2. запустить сервисы
ssh -i "$KEY" "$HOST" "cd $DIR && docker compose pull && docker compose up -d"

# 3. проверить доступность через скрипт мониторинга
ssh -i "$KEY" "$HOST" "cd $DIR && bash check_api.sh http://localhost:80"
```
Ожидаемый результат последней команды: `API доступен` и код возврата 0.
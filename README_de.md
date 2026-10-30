# offline-coder-cpu

Lokale, vom Internet unabhängige KI-Umgebung zum Programmieren. Die Modelle
laufen auf der CPU des eigenen Rechners in rootless Podman-Containern. Als
Oberfläche dient ausschließlich Open WebUI, mit Projekten (Ordnern), eigenen
System-Prompts, angehängtem Wissen und Gedächtnis, ähnlich wie bei
Cloud-Chatdiensten.

Diese Fassung ist ausgelegt für ein Notebook mit 4 CPU-Kernen ohne
dedizierte GPU (z.B. HP EliteBook 850 G8, i5-1135G7 mit 16 GB RAM).

Die englische Fassung dieser Beschreibung steht in [README.md](README.md).

## 1. Was es ist

offline-coder-cpu besteht aus zwei Containern, optional drei:

| Container                 | Aufgabe                                                                         |
|---------------------------|---------------------------------------------------------------------------------|
| `offline-coder-cpu-webui` | Open WebUI, die Weboberfläche im Browser                                        |
| `offline-coder-cpu-chat`  | llama-server (llama.cpp) mit dem Chat-Modell                                    |
| `offline-coder-cpu-fim`   | optional: llama-server für die Code-Vervollständigung in VS Code (llama-vscode) |

Aufbau:

```
Browser --> 127.0.0.1:3000 --> [ webui ] --> offline-coder-cpu-chat:8080
                                                (nur im Container-Netz)
VS Code --> 127.0.0.1:8012 --> [ fim ]          (nur mit AUTOCOMPLETE=1)
```

Der Chat-Container hat keinen Port auf dem Host und keine eigene
Weboberfläche. Er ist nur für Open WebUI erreichbar.

## 2. Was es macht

- Chat mit einem lokalen Sprachmodell, auch ohne Netzwerkverbindung.
  Standard mit 16 GB RAM ist Qwen3.5-9B, mit 64 GB Qwen3.6-35B-A3B
  (Auswahl siehe Abschnitt 9).
- **Projekte in Open WebUI:** Ordner mit eigenem System-Prompt und
  angehängtem Wissen. Neue Chats in einem Ordner übernehmen diese
  Einstellungen.
- **Dateien und Wissensbasen:** Texte und Quellcode werden lokal in
  Abschnitte zerlegt und durchsucht. Das dafür nötige Embedding-Modell wird
  bei der Einrichtung aus dem Open-WebUI-Image übernommen.
- **Kein Datenabfluss:** Modelle werden einmalig auf dem Host geladen. Danach
  arbeiten llama-server (`--offline`) und Open WebUI (`OFFLINE_MODE`) ohne
  Internetzugriff. Telemetrie und Update-Prüfungen sind abgeschaltet.
- Die Ports sind standardmäßig nur an `127.0.0.1` gebunden.
- **Hinweis zur Verschlüsselung:** `setup.sh` prüft, ob die Daten von
  Open WebUI auf einem mit LUKS/dm-crypt verschlüsselten Datenträger liegen,
  und gibt andernfalls einen Hinweis aus. Die Einrichtung läuft in beiden
  Fällen weiter (`REQUIRE_ENCRYPTION`).

## 3. Voraussetzungen

### Hardware

- **Arbeitsspeicher:** mindestens 16 GB. Mit 16 GB ist ein Modell der
  Größenklasse 9B mit 16K Kontext nutzbar, neben Desktop, Browser und
  VS Code allerdings knapp. Die MoE-Modelle aus Abschnitt 9 benötigen 64 GB.
- **CPU:** x86_64 mit AVX2 (empfohlen) oder aarch64, mindestens 4 Kerne.
  Auf der CPU begrenzt die Speicherbandbreite die Geschwindigkeit, zwei
  RAM-Module (Dual-Channel) sind deutlich schneller als eines.
- **Speicherplatz** im Projektverzeichnis:

| Größe       | Verwendung                                            |
|-------------|-------------------------------------------------------|
| 6 - 34 GB   | Chat-Modell, je nach Auswahl (Abschnitt 9)            |
| ca. 2 GB    | Modell für Autovervollständigung (optional)           |
| ab 2 GB     | Daten von Open WebUI (wachsen mit Chats und Uploads)  |

  Beim Modellwechsel liegen altes und neues Modell vorübergehend
  nebeneinander. Die Images (ca. 8 GB) liegen im Podman-Speicher des
  Benutzers (Standard: `~/.local/share/containers/storage`, den genauen
  Pfad zeigt `./setup.sh --check`).

### Verschlüsselung

Chats, Uploads und Wissen liegen im Projektverzeichnis (`data/webui/`).
Empfohlen, aber keine Voraussetzung, ist deshalb ein mit LUKS
verschlüsselter Datenträger, z.B. eine eigene Partition wie `/DATA`, die
beim Booten über eine Schlüsseldatei auf der ebenfalls verschlüsselten
Root-Partition entsperrt wird (Einträge in `/etc/crypttab` und
`/etc/fstab`), oder das Home-Verzeichnis auf einer verschlüsselten
Root-Partition.

Liegen die Daten unverschlüsselt, gibt `setup.sh` nur einen Hinweis aus.
Mit `REQUIRE_ENCRYPTION=1` in `setup.conf` bricht `setup.sh` stattdessen ab,
z.B. wenn eigene Vorgaben eine verschlüsselte Ablage verlangen.

### Software

- Linux (ausgelegt auf Linux Mint 22 / Ubuntu 24.04)
- Podman ab 4.0, rootless eingerichtet (Einträge in `/etc/subuid` und
  `/etc/subgid` für den Benutzer)
- Netzwerk-Backend netavark mit aardvark-dns
- podman-compose (empfohlen) oder docker-compose v2 mit aktivem
  Podman-Socket
- curl, coreutils, gawk, sed, grep, iproute2 (`ss`), util-linux (`lsblk`,
  `findmnt`)
- git (zum Klonen des Repositorys)

Installation unter Debian/Ubuntu/Mint:

```
sudo apt install podman podman-compose aardvark-dns curl iproute2 git
```

### Netzwerk

Nur für die erste Einrichtung bzw. Aktualisierungen: Zugriff auf
`huggingface.co` (Modelle) und `ghcr.io` (Images).

`setup.sh` prüft alle diese Punkte, bevor etwas verändert wird.

## 4. Dateien

| Datei           | Inhalt                                                   |
|-----------------|----------------------------------------------------------|
| `README.md`     | Beschreibung auf Englisch                                |
| `README_de.md`  | diese Beschreibung (Deutsch)                             |
| `.gitignore`    | Ausschlüsse für Git (Modelle, Daten, Schlüssel, Logs)    |
| `setup.conf`    | Konfiguration mit Standardwerten (Pfade, Ports, Modelle) |
| `setup.sh`      | Prüfung der Voraussetzungen und Einrichtung              |
| `ctl.sh`        | Bedienung im Alltag (start, stop, status, logs)          |
| `cleanup.sh`    | vollständiges Entfernen                                  |
| `common.sh`     | gemeinsame Funktionen der Skripte                        |
| `compose.yaml`  | Definition der Container                                 |
| `Dockerfile`    | Image für llama-server                                   |
| `entrypoint.sh` | Startskript von llama-server im Container                |

Von `setup.sh` erzeugt (nicht von Hand bearbeiten):

| Datei / Verzeichnis      | Inhalt                                         |
|--------------------------|------------------------------------------------|
| `.env`                   | Werte für compose.yaml, erzeugt aus setup.conf |
| `.webui_secret`          | Sitzungsschlüssel für Open WebUI               |
| `.offline-coder-cpu.log` | Ausgaben von Build und Compose                 |
| `models/`                | Modelle (Standardpfad)                         |
| `data/webui/`            | Daten von Open WebUI (Standardpfad)            |

Keine dieser Dateien gehört ins Repository, `.gitignore` schließt sie aus.

## 5. Einrichtung

```
git clone https://github.com/nnebojsa/offline-coder-cpu.git
cd offline-coder-cpu
vim setup.conf          # optional, Standardwerte passen für 16 GB RAM
./setup.sh --check      # nur prüfen
./setup.sh              # einrichten und starten
```

Das Verzeichnis ist frei wählbar, empfohlen ist ein verschlüsselter
Datenträger (siehe Abschnitt 3).

Danach ist die Oberfläche unter <http://127.0.0.1:3000> erreichbar. Das erste
dort angelegte Konto wird Administrator. Das Konto ist lokal und wird in
`data/webui/webui.db` gespeichert.

`setup.sh` ist wiederholbar. Vorhandene Modelle werden nicht erneut geladen,
abgebrochene Downloads werden fortgesetzt. Die Container werden bei jedem
Aufruf neu angelegt, Daten und Modelle bleiben dabei erhalten.

| Option                  | Wirkung                                        |
|-------------------------|------------------------------------------------|
| `./setup.sh --check`    | nur Voraussetzungen und Konfiguration prüfen   |
| `./setup.sh --no-start` | einrichten, Container nicht starten            |
| `./setup.sh --update`   | zusätzlich neueste Images laden                |

## 6. Konfiguration (setup.conf)

Alle Werte sind in `setup.conf` kommentiert. Nach jeder Änderung:

```
./setup.sh
```

Die wichtigsten Werte:

| Schlüssel                | Bedeutung                                         |
|--------------------------|---------------------------------------------------|
| `MODELS_DIR`             | Ablage der Modelle (Standard: `./models`)         |
| `WEBUI_DATA_DIR`         | Daten von Open WebUI (Standard: `./data/webui`)   |
| `BIND_ADDRESS`           | `127.0.0.1` = nur lokal erreichbar                |
| `WEBUI_PORT`             | Port der Oberfläche (Standard: 3000)              |
| `WEBUI_IMAGE`            | Version von Open WebUI                            |
| `WEBUI_AUTH`             | 1 = Anmeldung, 0 = ohne (nur bei Neuinstallation) |
| `WEBUI_OFFLINE`          | 1 = keine Downloads durch Open WebUI              |
| `WEBUI_TITLE_GENERATION` | automatische Chat-Titel durch das Modell          |
| `WEBUI_BACKGROUND_TASKS` | Tags, Folgefragen, Suchanfragen durch das Modell  |
| `CHAT_MODEL_REPO/_FILE`  | Chat-Modell auf Hugging Face                      |
| `CHAT_CTX`               | Kontextgröße in Tokens                            |
| `CHAT_SAMPLING`          | Sampling-Profil: qwen, qwen-coder, gemma, default |
| `CHAT_ALIAS`             | Modellname in Open WebUI                          |
| `CHAT_THREADS`           | CPU-Threads, `auto` = physische Kerne             |
| `CHAT_THINKING`          | Denk-Modus (langsamer, gründlicher)               |
| `AUTOCOMPLETE`           | 1 = Container für die VS-Code-Vervollständigung   |
| `MIN_RAM_GB`             | Mindest-RAM für die Prüfung (Standard: 16)        |
| `RESERVED_RAM_GB`        | RAM für System, Desktop, Browser, VS Code (6)     |
| `REQUIRE_ENCRYPTION`     | unverschlüsselt: 0 = Hinweis (Std.), 1 = Abbruch  |

> **Hinweis zu Open WebUI:** Werte wie Titel-Generierung,
> Hintergrund-Aufgaben oder Standardmodell übernimmt Open WebUI nur beim
> ersten Start. Danach gelten die Einstellungen im Admin-Panel. Mit
> `WEBUI_CONFIG_FROM_ENV=1` gelten die Werte aus `setup.conf` bei jedem
> Start, Änderungen im Admin-Panel gehen dann aber beim Neustart verloren.

## 7. Bedienung

| Befehl               | Wirkung                                        |
|----------------------|------------------------------------------------|
| `./ctl.sh start`     | starten, z.B. nach einem Neustart des Rechners |
| `./ctl.sh stop`      | anhalten, der Arbeitsspeicher wird frei        |
| `./ctl.sh restart`   | anhalten und wieder starten                    |
| `./ctl.sh status`    | Zustand, Bereitschaft, RAM- und CPU-Verbrauch  |
| `./ctl.sh logs chat` | Log des Chat-Containers (auch: webui, fim)     |

Nach einem Neustart des Rechners laufen die Container nicht automatisch, der
Start erfolgt mit `./ctl.sh start`. Das Laden des Modells dauert je nach
Größe zwischen 20 Sekunden und wenigen Minuten.

## 8. Projekte in Open WebUI

- Neuer Ordner in der Seitenleiste, über das Menü des Ordners
  **Bearbeiten**: Name, System-Prompt und Wissen festlegen.
- Wissen anlegen unter **Arbeitsbereich > Wissen**, Dateien hochladen und
  die Wissensbasis dem Ordner zuweisen.
- Chats in diesem Ordner erhalten automatisch System-Prompt und Wissen.

Empfehlungen für die CPU:

- Pro Thema einen neuen Chat beginnen. Der gesamte Verlauf wird bei jeder
  Antwort mitgeschickt und verlängert die Wartezeit.
- Bei Wissensbasen die Standard-Suche (RAG) verwenden, nicht den Modus mit
  vollem Kontext. Der volle Kontext sprengt schnell `CHAT_CTX`.
- Wenige, gezielte Dateien pro Projekt anhängen.

## 9. Modelle und Modellwechsel

`setup.conf` enthält für jedes Modell einen Block aus vier Zeilen
(`CHAT_MODEL_REPO`, `CHAT_MODEL_FILE`, `CHAT_CTX`, `CHAT_SAMPLING`). Genau
ein Block ist aktiv.

| Modell           | Hersteller | Gesamt / aktiv | Datei     | RAM   | Einsatz                         |
|------------------|------------|----------------|-----------|-------|---------------------------------|
| Qwen3.5-9B       | Alibaba    | 9B (dicht)     | ca. 6 GB  | 16 GB | Standard bei 16 GB RAM          |
| Qwen3.6-35B-A3B  | Alibaba    | 35B / 3B       | ca. 21 GB | 64 GB | Standard bei 64 GB RAM          |
| Gemma 4 26B-A4B  | Google     | 25B / 3,8B     | ca. 16 GB | 64 GB | Alternative zum Vergleich       |
| Qwen3-Coder-Next | Alibaba    | 80B / 3B       | ca. 34 GB | 64 GB | Coding-Spezialist, 3-Bit, knapp |

Alle Modelle stehen unter Apache 2.0. Auf der CPU sind nur Modelle mit
wenigen aktiven Parametern je Token schnell genug, deshalb fehlen dichte
Modelle wie Qwen3.8-27B. Qwen3-Coder-Next belegt allein für die
Modelldatei rund 34 GB und ist nur sinnvoll, wenn daneben wenige Programme
laufen. Es hat keinen Denk-Modus.

Wechsel, z.B. nach einem RAM-Ausbau auf 64 GB:

1. In `setup.conf` den Block "16 GB RAM: Standard" auskommentieren und den
   Block "64 GB RAM: Standard" aktivieren.
2. `./setup.sh --check`, danach `./setup.sh`.

Das Modell wird geladen, die Container werden neu angelegt. Der Modellname
in Open WebUI (`CHAT_ALIAS`) bleibt gleich, Projekte und Standardmodell
passen weiterhin. Die zuvor genutzte Modelldatei kann danach aus
`MODELS_DIR` gelöscht werden.

`setup.sh` warnt, wenn `CHAT_SAMPLING` nicht zum Modell passt, und
schätzt den RAM-Bedarf ab (Modell, Kontext, Open WebUI und
`RESERVED_RAM_GB`).

## 10. Autovervollständigung in VS Code (optional)

```
# AUTOCOMPLETE=1 in setup.conf, danach:
./setup.sh
code --install-extension ggml-org.llama-vscode
```

Die Erweiterung nutzt standardmäßig `http://127.0.0.1:8012`. Das Angebot der
Erweiterung, llama.cpp zu installieren, ist abzulehnen, da der Server bereits
im Container läuft. Benötigt zusätzlich ca. 2 GB RAM.

## 11. Offline-Betrieb und Datenschutz

- Nach der Einrichtung ist keine Internetverbindung mehr nötig.
- `OFFLINE_MODE` und `--offline` unterbinden Downloads, blockieren aber keine
  Verbindungen. Für eine harte Trennung sind Firewall-Regeln nötig.
- Chats und hochgeladene Dateien liegen in `WEBUI_DATA_DIR`. Sensible Inhalte
  (z.B. Logs mit personenbezogenen Daten) nach der Analyse löschen.
- `WEBUI_DATA_DIR` und der Sitzungsschlüssel `.webui_secret` liegen im
  Projektverzeichnis. Liegt es auf einem verschlüsselten Datenträger, sind
  sie bei ausgeschaltetem Rechner ohne Passphrase nicht lesbar. Im
  laufenden Betrieb sind sie wie alle anderen Dateien zugänglich.
- Ob vertrauliche Daten auf dem Rechner verarbeitet werden dürfen, regeln die
  internen Vorgaben, auch wenn das Modell lokal läuft.

## 12. Aktualisierung

```
./setup.sh --update
```

Lädt das in `WEBUI_IMAGE` angegebene Open-WebUI-Image und das
llama.cpp-Basis-Image neu und baut das llama-server-Image. Für eine neue
Version von Open WebUI zuerst `WEBUI_IMAGE` in `setup.conf` anpassen. Vor
einem Versionswechsel empfiehlt sich eine Sicherung von `WEBUI_DATA_DIR` bei
angehaltenen Containern (`./ctl.sh stop`).

## 13. Entfernen

| Befehl                        | Wirkung                          |
|-------------------------------|----------------------------------|
| `./cleanup.sh`                | alles entfernen                  |
| `./cleanup.sh --keep-models`  | Modelle behalten                 |
| `./cleanup.sh --keep-data`    | Daten von Open WebUI behalten    |
| `./cleanup.sh -y`             | ohne Abfrage                     |

Entfernt Container, Pod, Netzwerk, Images, Modelle, die Daten von Open WebUI
und die erzeugten Dateien. Laufen noch Container, werden sie angezeigt und es
folgt eine Abfrage (y/n). Ohne laufende Container erfolgt das Entfernen ohne
Rückfrage. Die Projektdateien selbst bleiben erhalten.

Liegt `MODELS_DIR` außerhalb des Projektverzeichnisses, werden dort nur die
konfigurierten Modelldateien gelöscht, nicht das ganze Verzeichnis.

## 14. Fehlersuche

**Prüfung der Voraussetzungen**

```
./setup.sh --check
```

**Logs**

```
./ctl.sh logs chat
./ctl.sh logs webui
less .offline-coder-cpu.log
```

**Modell erscheint nicht in Open WebUI**

Der Chat-Container lädt noch das Modell. `./ctl.sh status` zeigt, ob er
bereit ist. Danach die Seite neu laden.

**"aardvark pid not found" bzw. Open WebUI erreicht den Chat nicht**

```
podman rm -f offline-coder-cpu-chat offline-coder-cpu-webui offline-coder-cpu-fim
podman network rm offline-coder-cpu_default
rm -rf /run/user/$(id -u)/containers/networks/aardvark-dns
./setup.sh
```

**Fehler "context size exceeded" im Chat**

Verlauf und Anhänge sind größer als `CHAT_CTX`. Neuen Chat beginnen, weniger
Dateien anhängen oder `CHAT_CTX` erhöhen (benötigt mehr RAM).

**Antworten brechen nach einigen Minuten ab**

`WEBUI_REQUEST_TIMEOUT` in `setup.conf` erhöhen, danach `./setup.sh`.

**"liegt auf einem unverschlüsselten Datenträger"**

Der Datenträger mit dem Projektverzeichnis ist nicht mit LUKS
verschlüsselt. Standardmäßig ist das nur ein Hinweis, ein Fehler nur mit
`REQUIRE_ENCRYPTION=1`. Prüfung im Projektverzeichnis:

```
findmnt --target .
lsblk -f
```

Erwartet: Die Quelle ist ein Gerät unter `/dev/mapper/`, und `lsblk -f`
zeigt darüber eine Partition vom Typ `crypto_LUKS`.

**Wie schnell ist das Modell?**

`./ctl.sh logs chat` zeigt nach jeder Antwort die Werte `prompt eval`
(Einlesen des Prompts) und `eval` (Schreiben der Antwort) in Tokens pro
Sekunde.

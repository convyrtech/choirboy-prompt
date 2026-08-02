# Coldcard entropy heist — источники

Собрано 2026-08-02 через Tavily (research + search + extract). Приоритет —
первоисточники (Coinkite, Block), затем подтверждающая пресса.

## Первоисточники

- **Coinkite — Mk3 Security Advisory** (что делать, диапазоны прошивок,
  исключение по костям):
  https://blog.coinkite.com/coldcard-mk3-seed-generation-warning
- **Coinkite — Technical Deep Dive into the Entropy Issue** (техбэкграундер:
  ckcc.rng_bytes → ngu.random.bytes, MicroPython fallback, почему ревью
  проглядел, признание про ИИ-аудит):
  https://blog.coinkite.com/entropy-technical-backgrounder
- **Block Bitcoin Engineering — Predictable RNG Fallback and 32-Bit Reseed
  in COLDCARD Firmware** (root-cause, C-сниппеты guard и init Yasmarang,
  32-битный reseed Mk4, хронология git-blame):
  https://engineering.block.xyz/blog/predictable-rng-fallback-and-32-bit-reseed-in-coldcard-firmware

## Подтверждающая пресса / аналитика

- CoinDesk — Major bitcoin wallet flaw drains 594 BTC in 25-minute sweep:
  https://www.coindesk.com/tech/2026/07/31/major-bitcoin-wallet-flaw-drains-594-btc-in-25-minute-sweep
- KuCoin flash — Coldcard Wallet Entropy Flaw Leads to $38M Bitcoin Theft
  (окно 01:31–01:56 UTC, bc1qnk… консолидатор, разбор TRNG/PRNG):
  https://www.kucoin.com/news/flash/coldcard-wallet-entropy-flaw-leads-to-38m-bitcoin-theft
- TechTimes — деталь коммита (rng_bytes → ngu.random.bytes 2021-03-01),
  Mk4 boot-reseed 32B SE1 + 8B SE2 → 4 байта в reseed():
  https://www.techtimes.com/articles/322392/20260731/coldcard-hardware-wallet-hacked-via-firmware-bug-that-bypassed-rng-five-years.htm
- beincrypto / Yahoo — Yasmarang init из UID/SysTick/RTC, RTC-осциллятор
  выключен на Mk3, ~четыре млрд комбинаций (2^32) для Mk4:
  https://beincrypto.com/coldcard-rng-flaw-bitcoin-theft
- Cryptopolitan — оценка Galaxy Research 1 082.65 BTC / $70M / 1 196
  адресов; цитата Block про Clay Garrett и ончейн-трейл:
  https://www.cryptopolitan.com/coldcard-biggest-security-failure-cost-70m
- Cryptonomist — пороги костей (50–98 → 128 бит, 99+ → 256 бит),
  TAPSIGNER/OPENDIME/SATSCARD не затронуты:
  https://en.cryptonomist.ch/2026/07/31/coinkite-seed-vulnerability-theft
- Bitcoin Well — таймлайн, миграция на libsecp256k1/libNgU, «8 лет» =
  возраст upstream-кода MicroPython, а не срок уязвимой генерации:
  https://bitcoinwell.com/coldcard-vulnerability
- Forbes — общий охват, цитата Coinkite «We were unaware of the bug until
  today», предупреждение про импорт seed в другие кошельки:
  https://www.forbes.com/sites/digital-assets/2026/07/31/massive-surprise-bitcoin-attack-sparks-sudden-price-crash-fears

## Смежный класс (для контекста, не по Coldcard)

- Milk Sad — CVE-2023-39910 (libbitcoin bx seed, mt19937, 32-битный сид):
  https://nvd.nist.gov/vuln/detail/CVE-2023-39910 ; https://milksad.info/disclosure.html
- Trust Wallet Core — CVE-2023-31290 (энтропия сжата до 32 бит):
  https://nvd.nist.gov/vuln/detail/CVE-2023-31290
- Vasek et al., «The Bitcoin Brain Drain» (98% brainwallet вскрыты,
  медиана дренажа — секунды/минуты):
  https://mvasek.com/static/papers/vasekfc16.pdf

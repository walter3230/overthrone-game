const canvas = document.getElementById("gameCanvas");
const ctx = canvas.getContext("2d");

const ui = {
  gold: document.getElementById("gold"),
  loot: document.getElementById("loot"),
  castleHp: document.getElementById("castleHp"),
  wave: document.getElementById("wave"),
  towerList: document.getElementById("towerList"),
  heroList: document.getElementById("heroList"),
  statusLog: document.getElementById("statusLog"),
  enemyCastleLevel: document.getElementById("enemyCastleLevel"),
  successChance: document.getElementById("successChance"),
  pvpResult: document.getElementById("pvpResult"),
  startWaveBtn: document.getElementById("startWaveBtn"),
  nextEnemySetBtn: document.getElementById("nextEnemySetBtn"),
  pvpAttackBtn: document.getElementById("pvpAttackBtn")
};

const state = {
  wave: 1,
  gold: 240,
  loot: 80,
  castleHp: 100,
  enemies: [],
  towers: [],
  projectiles: [],
  waveRunning: false,
  enemySetLevel: 1,
  spawnLeft: 0,
  spawnTick: 0,
  enemyCastleLevel: 1,
  path: [
    { x: 0, y: 340 },
    { x: 170, y: 340 },
    { x: 170, y: 125 },
    { x: 460, y: 125 },
    { x: 460, y: 285 },
    { x: 740, y: 285 },
    { x: 740, y: 160 },
    { x: 960, y: 160 }
  ],
  towerTypes: [
    { name: "Okçu Kulesi", damage: 9, range: 118, cooldown: 40, price: 85, color: "#66d9ff" },
    { name: "Bomba Kulesi", damage: 16, range: 95, cooldown: 65, price: 130, color: "#ff9d57" },
    { name: "Buz Kulesi", damage: 6, range: 126, cooldown: 55, price: 110, slow: 0.82, color: "#9bd8ff" }
  ],
  heroes: [
    { name: "Alara", level: 1, attack: 12, hp: 140, upgradeCost: 45 },
    { name: "Brakk", level: 1, attack: 16, hp: 180, upgradeCost: 65 },
    { name: "Nyx", level: 1, attack: 10, hp: 120, upgradeCost: 50 },
    { name: "Korin", level: 1, attack: 19, hp: 160, upgradeCost: 90 }
  ],
  enemyTypesByLevel: [
    [
      { name: "Goblin", hp: 36, speed: 1.2, reward: 12, color: "#95ff72", size: 10 },
      { name: "Yaban Domuzu", hp: 60, speed: 0.92, reward: 15, color: "#dcb48f", size: 12 }
    ],
    [
      { name: "Ork", hp: 92, speed: 0.95, reward: 18, color: "#74d55b", size: 12 },
      { name: "Kalkanlı", hp: 140, speed: 0.68, reward: 22, color: "#9fb8cc", size: 13 }
    ],
    [
      { name: "Nekromant", hp: 180, speed: 0.85, reward: 28, color: "#b49dff", size: 13 },
      { name: "Ejder Yavrusu", hp: 240, speed: 1.32, reward: 34, color: "#ff7f89", size: 12 }
    ],
    [
      { name: "Obsidyen Dev", hp: 410, speed: 0.58, reward: 60, color: "#ffb3b3", size: 16 },
      { name: "Abyss Lord", hp: 620, speed: 0.79, reward: 95, color: "#ff5ac8", size: 17 }
    ]
  ]
};

function clamp(v, min, max) {
  return Math.max(min, Math.min(max, v));
}

function logStatus(text) {
  ui.statusLog.textContent = text;
}

function calcPvPPower() {
  const heroPower = state.heroes.reduce((sum, hero) => sum + hero.attack * hero.level + hero.hp * 0.07, 0);
  const towerPower = state.towers.length * 18;
  return heroPower + towerPower + state.wave * 9;
}

function calcSuccessChance() {
  const myPower = calcPvPPower();
  const enemyPower = 120 + state.enemyCastleLevel * 70;
  const ratio = myPower / (enemyPower + myPower);
  return clamp(Math.round(ratio * 100), 8, 95);
}

function updateUI() {
  ui.gold.textContent = Math.floor(state.gold);
  ui.loot.textContent = Math.floor(state.loot);
  ui.castleHp.textContent = Math.max(0, Math.floor(state.castleHp));
  ui.wave.textContent = state.wave;
  ui.enemyCastleLevel.textContent = state.enemyCastleLevel;
  ui.successChance.textContent = `${calcSuccessChance()}%`;

  ui.towerList.innerHTML = "";
  state.towerTypes.forEach((towerType, index) => {
    const adjustedPrice = Math.round(towerType.price * (1 + state.wave * 0.06));
    const li = document.createElement("li");
    li.innerHTML = `<span><strong>${towerType.name}</strong><br>Hasar: ${towerType.damage} | Menzil: ${towerType.range} | Fiyat: ${adjustedPrice}</span>`;
    const buyButton = document.createElement("button");
    buyButton.textContent = "Seç";
    buyButton.className = "small-btn";
    buyButton.onclick = () => {
      state.selectedTowerIndex = index;
      logStatus(`Yerleştirmek için haritaya tıkla: ${towerType.name}`);
    };
    li.appendChild(buyButton);
    ui.towerList.appendChild(li);
  });

  ui.heroList.innerHTML = "";
  state.heroes.forEach((hero, index) => {
    const li = document.createElement("li");
    li.innerHTML = `<span><strong>${hero.name}</strong> Lv.${hero.level}<br>ATK: ${hero.attack} | HP: ${hero.hp} | Geliştir: ${hero.upgradeCost} ganimet</span>`;
    const upButton = document.createElement("button");
    upButton.className = "small-btn";
    upButton.textContent = "Yükselt";
    upButton.onclick = () => upgradeHero(index);
    li.appendChild(upButton);
    ui.heroList.appendChild(li);
  });
}

function pickEnemyType() {
  const tier = state.enemyTypesByLevel[clamp(state.enemySetLevel - 1, 0, state.enemyTypesByLevel.length - 1)];
  const raw = tier[Math.floor(Math.random() * tier.length)];
  const scaling = 1 + (state.wave - 1) * 0.18;
  return {
    name: raw.name,
    hp: raw.hp * scaling,
    baseHp: raw.hp * scaling,
    speed: raw.speed * (1 + (state.wave - 1) * 0.02),
    reward: Math.round(raw.reward * (1 + (state.wave - 1) * 0.11)),
    color: raw.color,
    size: raw.size,
    x: state.path[0].x,
    y: state.path[0].y,
    pathIndex: 1,
    slowMultiplier: 1,
    alive: true
  };
}

function startWave() {
  if (state.waveRunning) {
    logStatus("Dalga zaten sürüyor.");
    return;
  }
  state.spawnLeft = 6 + state.wave * 2;
  state.spawnTick = 0;
  state.waveRunning = true;
  logStatus(`Dalga ${state.wave} başladı! Düşmanlar güçleniyor...`);
}

function finishWaveIfDone() {
  if (state.waveRunning && state.spawnLeft <= 0 && state.enemies.length === 0) {
    state.waveRunning = false;
    state.wave += 1;
    state.gold += 70 + state.wave * 12;
    state.loot += 20 + state.wave * 6;
    logStatus(`Dalga temizlendi! Ödül kazandın. Sonraki dalga: ${state.wave}`);
    updateUI();
  }
}

function spawnEnemies() {
  if (!state.waveRunning || state.spawnLeft <= 0) return;
  state.spawnTick += 1;
  const spawnDelay = Math.max(18, 50 - state.wave * 2);
  if (state.spawnTick >= spawnDelay) {
    state.spawnTick = 0;
    state.spawnLeft -= 1;
    state.enemies.push(pickEnemyType());
  }
}

function updateEnemies() {
  for (let i = state.enemies.length - 1; i >= 0; i -= 1) {
    const enemy = state.enemies[i];
    const target = state.path[enemy.pathIndex];
    if (!target) {
      state.castleHp -= 7 + state.wave * 0.9;
      state.enemies.splice(i, 1);
      if (state.castleHp <= 0) {
        state.castleHp = 0;
        state.waveRunning = false;
        state.enemies = [];
        logStatus("Kalene saldırıldı! Savunma düştü, oyun sıfırlandı.");
        softReset();
      }
      continue;
    }

    const dx = target.x - enemy.x;
    const dy = target.y - enemy.y;
    const dist = Math.hypot(dx, dy) || 1;
    const speed = enemy.speed * enemy.slowMultiplier;
    enemy.x += (dx / dist) * speed;
    enemy.y += (dy / dist) * speed;
    enemy.slowMultiplier = Math.min(1, enemy.slowMultiplier + 0.005);

    if (dist < 5) {
      enemy.pathIndex += 1;
    }
  }
}

function updateTowers() {
  state.towers.forEach((tower) => {
    tower.cooldownLeft -= 1;
    if (tower.cooldownLeft > 0) return;

    let nearest = null;
    let nearestDist = Infinity;
    state.enemies.forEach((enemy) => {
      const d = Math.hypot(enemy.x - tower.x, enemy.y - tower.y);
      if (d < tower.range && d < nearestDist) {
        nearest = enemy;
        nearestDist = d;
      }
    });

    if (nearest) {
      tower.cooldownLeft = tower.cooldown;
      state.projectiles.push({
        x: tower.x,
        y: tower.y,
        target: nearest,
        speed: 4.8,
        damage: tower.damage,
        color: tower.color,
        slow: tower.slow || 1
      });
    }
  });
}

function updateProjectiles() {
  for (let i = state.projectiles.length - 1; i >= 0; i -= 1) {
    const p = state.projectiles[i];
    if (!p.target || !state.enemies.includes(p.target)) {
      state.projectiles.splice(i, 1);
      continue;
    }

    const dx = p.target.x - p.x;
    const dy = p.target.y - p.y;
    const dist = Math.hypot(dx, dy) || 1;
    p.x += (dx / dist) * p.speed;
    p.y += (dy / dist) * p.speed;

    if (dist < 8) {
      p.target.hp -= p.damage;
      p.target.slowMultiplier *= p.slow;
      if (p.target.hp <= 0) {
        state.gold += p.target.reward;
        state.loot += Math.max(4, Math.floor(p.target.reward * 0.35));
        state.enemies = state.enemies.filter((e) => e !== p.target);
      }
      state.projectiles.splice(i, 1);
      updateUI();
    }
  }
}

function drawPath() {
  ctx.strokeStyle = "#53609a";
  ctx.lineWidth = 26;
  ctx.lineJoin = "round";
  ctx.beginPath();
  ctx.moveTo(state.path[0].x, state.path[0].y);
  for (let i = 1; i < state.path.length; i += 1) {
    ctx.lineTo(state.path[i].x, state.path[i].y);
  }
  ctx.stroke();
}

function drawEntities() {
  state.towers.forEach((tower) => {
    ctx.fillStyle = tower.color;
    ctx.beginPath();
    ctx.arc(tower.x, tower.y, 12, 0, Math.PI * 2);
    ctx.fill();
  });

  state.enemies.forEach((enemy) => {
    ctx.fillStyle = enemy.color;
    ctx.beginPath();
    ctx.arc(enemy.x, enemy.y, enemy.size, 0, Math.PI * 2);
    ctx.fill();

    const hpPct = clamp(enemy.hp / (enemy.baseHp || enemy.hp), 0, 1);
    ctx.fillStyle = "#18223c";
    ctx.fillRect(enemy.x - 15, enemy.y - enemy.size - 10, 30, 4);
    ctx.fillStyle = "#67ff95";
    ctx.fillRect(enemy.x - 15, enemy.y - enemy.size - 10, 30 * hpPct, 4);
  });

  state.projectiles.forEach((projectile) => {
    ctx.fillStyle = projectile.color;
    ctx.beginPath();
    ctx.arc(projectile.x, projectile.y, 3, 0, Math.PI * 2);
    ctx.fill();
  });

  ctx.fillStyle = "#eaf1ff";
  ctx.font = "bold 14px sans-serif";
  ctx.fillText("Kale", 905, 140);
  ctx.fillStyle = "#95b4ff";
  ctx.fillRect(900, 150, 40, 50);
}

function render() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  drawPath();
  drawEntities();
}

function gameLoop() {
  spawnEnemies();
  updateEnemies();
  updateTowers();
  updateProjectiles();
  finishWaveIfDone();
  render();
  requestAnimationFrame(gameLoop);
}

function upgradeHero(index) {
  const hero = state.heroes[index];
  if (state.loot < hero.upgradeCost) {
    logStatus(`${hero.name} için yeterli ganimet yok.`);
    return;
  }
  state.loot -= hero.upgradeCost;
  hero.level += 1;
  hero.attack = Math.round(hero.attack * 1.2 + 2);
  hero.hp = Math.round(hero.hp * 1.13 + 7);
  hero.upgradeCost = Math.round(hero.upgradeCost * 1.45 + 12);
  logStatus(`${hero.name} geliştirildi! Seviye ${hero.level}`);
  updateUI();
}

function softReset() {
  state.wave = 1;
  state.castleHp = 100;
  state.gold = 240;
  state.loot = 80;
  state.enemyCastleLevel = 1;
  state.towers = [];
  state.projectiles = [];
  state.enemies = [];
  state.waveRunning = false;
  updateUI();
}

canvas.addEventListener("click", (event) => {
  if (typeof state.selectedTowerIndex !== "number") {
    logStatus("Önce kule seç.");
    return;
  }

  const rect = canvas.getBoundingClientRect();
  const x = ((event.clientX - rect.left) / rect.width) * canvas.width;
  const y = ((event.clientY - rect.top) / rect.height) * canvas.height;

  const tooCloseToPath = state.path.some((point) => Math.hypot(point.x - x, point.y - y) < 40);
  if (tooCloseToPath) {
    logStatus("Kuleyi yolun üstüne koyamazsın.");
    return;
  }

  const base = state.towerTypes[state.selectedTowerIndex];
  const cost = Math.round(base.price * (1 + state.wave * 0.06));
  if (state.gold < cost) {
    logStatus("Yeterli altın yok.");
    return;
  }

  state.gold -= cost;
  state.towers.push({
    x,
    y,
    damage: base.damage + Math.floor(state.wave * 0.4),
    range: base.range,
    cooldown: base.cooldown,
    cooldownLeft: 5,
    color: base.color,
    slow: base.slow
  });
  logStatus(`${base.name} kuruldu! (-${cost} altın)`);
  updateUI();
});

ui.startWaveBtn.addEventListener("click", startWave);

ui.nextEnemySetBtn.addEventListener("click", () => {
  if (state.enemySetLevel < state.enemyTypesByLevel.length) {
    state.enemySetLevel += 1;
    logStatus(`Yeni düşman türleri açıldı! Seviye ${state.enemySetLevel}`);
  } else {
    logStatus("Tüm düşman türleri zaten açık.");
  }
});

ui.pvpAttackBtn.addEventListener("click", () => {
  const chance = calcSuccessChance();
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= chance) {
    const lootGain = 70 + state.enemyCastleLevel * 35 + Math.round(calcPvPPower() * 0.06);
    const goldGain = 120 + state.enemyCastleLevel * 60;
    state.loot += lootGain;
    state.gold += goldGain;
    ui.pvpResult.textContent = `Zafer! ${lootGain} ganimet ve ${goldGain} altın yağmalandı.`;
    ui.pvpResult.className = "win";
    state.enemyCastleLevel += 1;
    logStatus("PvP baskını başarılı oldu. Rakipler güçleniyor.");
  } else {
    const loss = Math.round(20 + state.enemyCastleLevel * 8);
    state.gold = Math.max(0, state.gold - loss);
    ui.pvpResult.textContent = `Baskın başarısız! ${loss} altın kaybettin.`;
    ui.pvpResult.className = "lose";
    logStatus("PvP baskını başarısız. Daha güçlü kahramanlar geliştir.");
  }

  updateUI();
});

state.enemyTypesByLevel.forEach((tier) => {
  tier.forEach((enemy) => {
    enemy.baseHp = enemy.hp;
  });
});

updateUI();
gameLoop();

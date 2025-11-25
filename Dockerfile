# ==========================================
# 第一阶段：构建层 (Builder)
#这一层用来干脏活累活，体积大点没关系，最后会被丢弃
# ==========================================
FROM node:18-slim AS builder
WORKDIR /app

# 安装下载和解压工具
RUN apt-get update && apt-get install -y curl tar

# 1. 下载 Camoufox
ARG CAMOUFOX_URL
RUN if [ -z "$CAMOUFOX_URL" ]; then echo "Error: URL is empty"; exit 1; fi && \
    curl -sSL ${CAMOUFOX_URL} -o camoufox.tar.gz && \
    tar -xzf camoufox.tar.gz && \
    chmod +x camoufox-linux/camoufox

# 2. 安装 NPM 依赖
COPY package*.json ./
# 禁止自动下载浏览器
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_SKIP_DOWNLOAD=true \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=true
# 只安装依赖，不要任何开发工具
RUN npm install --omit=dev

# ==========================================
# 第二阶段：运行层 (Final)
# 这是一个全新的、干干净净的镜像
# ==========================================
FROM node:18-slim
WORKDIR /app

# 1. 安装运行浏览器必须的系统库
# 这些是 Camoufox 运行必须的，无法省略，但体积可控
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates fonts-liberation libasound2 libatk-bridge2.0-0 \
    libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 \
    libfontconfig1 libgbm1 libgcc1 libglib2.0-0 libgtk-3-0 libnspr4 \
    libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 \
    libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 \
    libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 \
    lsb-release wget xdg-utils xvfb \
    && rm -rf /var/lib/apt/lists/*

# 2. 【核心魔法】只从上一阶段拷贝结果，不拷贝过程！
# 把整理好的 node_modules 拿过来 (约 300MB-1GB)
COPY --from=builder /app/node_modules ./node_modules
# 把解压好的 camoufox 拿过来 (约 300-500MB)
COPY --from=builder /app/camoufox-linux ./camoufox-linux
# 拷贝 package.json
COPY package*.json ./

# 3. 拷贝你的代码文件
COPY unified-server.js black-browser.js ./

# 4. 权限设置
RUN mkdir -p ./auth && chown -R node:node /app

# 5. 启动配置
USER node
EXPOSE 7860 9998
ENV CAMOUFOX_EXECUTABLE_PATH=/app/camoufox-linux/camoufox
CMD ["node", "unified-server.js"]
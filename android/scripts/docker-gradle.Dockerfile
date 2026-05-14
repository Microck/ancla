FROM eclipse-temurin:17-jdk-jammy

ARG HOST_SDK_ROOT=/tmp/host-android-sdk

ENV DEBIAN_FRONTEND=noninteractive
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    git \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "$ANDROID_HOME/cmdline-tools"

COPY tmp/commandlinetools-linux-14742923_latest.zip /tmp/commandlinetools.zip

RUN unzip -q /tmp/commandlinetools.zip -d /tmp/android-cmdline-tools \
    && mkdir -p "$ANDROID_HOME/cmdline-tools/latest" \
    && cp -R /tmp/android-cmdline-tools/cmdline-tools/. "$ANDROID_HOME/cmdline-tools/latest/" \
    && rm -rf /tmp/android-cmdline-tools /tmp/commandlinetools.zip

RUN yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/dev/null \
    && sdkmanager --sdk_root="$ANDROID_HOME" \
      "platform-tools" \
      "platforms;android-35" \
      "build-tools;35.0.0"

COPY tmp/android-sdk-tools-static-aarch64/build-tools/aapt2 /tmp/android-aapt2/aapt2

RUN chmod +x /tmp/android-aapt2/aapt2

COPY tmp/android-sdk/licenses/ "$ANDROID_HOME/licenses/"

RUN mkdir -p /workspace /home/gradle/.gradle
RUN mkdir -p /home/gradle/.android && printf "{}\n" > /home/gradle/.android/analytics.settings

WORKDIR /workspace/android

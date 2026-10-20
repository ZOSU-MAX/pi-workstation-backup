/*
 * ESP32-C3 DNS AdBlock Sinkhole v2
 * 
 * 改进版：正确的DNS转发逻辑，广告域名sinkhole，正常域名转发上游DNS
 * 硬件：ESP32-C3
 * 库依赖：仅 ESP32 Arduino Core（内置WiFi/EEPROM）
 * 
 * 编译：Arduino IDE → 开发板选 "ESP32C3 Dev Module"
 */

#include <WiFi.h>
#include <WebServer.h>
#include <EEPROM.h>
#include <WiFiUdp.h>

// ============== 配置区域 ==============
const char* AP_SSID = "ESP32-ADBLOCK";
const char* AP_PASS = "12345678";
const int DNS_PORT = 53;
const char* UPSTREAM_DNS = "223.5.5.5";    // 上游DNS
const int UPSTREAM_PORT = 53;
// ====================================

WebServer webServer(80);
WiFiUDP dnsUdp;
bool wifiConfigured = false;
unsigned long lastCheck = 0;

// DNS包缓冲区
uint8_t dnsBuffer[512];
int dnsLen = 0;

// 广告域名黑名单
const char* adDomains[] = {
  "ad.qq.com","ad.sina.com.cn","ad.sina.com","ad.youku.com","ad.iqiyi.com",
  "ad.mi.com","ad.huawei.com","ad.oppo.com","ad.vivo.com","ad.meituan.com",
  "ad.taobao.com","ad.tmall.com","ad.alipay.com","ad.1688.com","ad.aliyun.com",
  "ad.baidu.com","ad.jd.com","ad.pinduoduo.com","ad.douyin.com",
  "ad.toutiao.com","ad.bytedance.com","ad.snssdk.com","ad.toutiaocdn.com",
  "ad.zijieapi.com","ad.oceanengine.com","ad.volceapplog.com",
  "ad.gtimg.com","ad.qlogo.cn","ad.qpic.cn",
  "doubleclick.net","googlesyndication.com","googleadservices.com",
  "google-analytics.com","adservice.google.com","adsrvr.org",
  "advertising.com","adnxs.com","adform.net","adsafeprotected.com",
  "criteo.com","criteo.net","taboola.com","outbrain.com",
  "pubmatic.com","openx.net","rubiconproject.com","casalemedia.com",
  "spotxchange.com","adx.com","adtechus.com","advertising.yahoo.com",
  "umeng.com","umengcloud.com","talkingdata.com","talkingdata.net",
  "appsflyer.com","adjust.com","kochava.com","branch.io",
  "admaster.com.cn","adsmogo.com","adview.com","adwo.com",
  "admob.com","inmobi.com","flurry.com","applovin.com",
  "mopub.com","chartboost.com","vungle.com","unityads.unity3d.com",
  "adcolony.com","tapjoy.com","leadbolt.com","smrtb.com",
  "adroll.com","exelator.com","mathtag.com","turn.com",
  "bluekai.com","demdex.net","krxd.net",
  "ad.music.163.com","ad.music.126.net","ad.kugou.com","ad.kuwo.cn",
  "ad.migu.cn","ad.video.qq.com","ad.v.qq.com","ad.pptv.com",
  "ad.mgtv.com","ad.le.com","ad.sohu.com","ad.56.com",
  "ad.leshu.com","ad.pps.tv","ad.ximalaya.com","ad.zhihu.com",
  "ad.360.cn","ad.so.com","ad.sogou.com","ad.yandex.com",
  "ad.babylon.com","ad.duitang.com","ad.meitu.com",
  "ad.tongji.baidu.com","ad.huazhu.com","ad.qunar.com",
  "ad.ctrip.com","ad.mafengwo.ad","ad.lvmama.com",
  "ad.xiaomi.com","ad.miui.com","ad.hicloud.com",
  "ad.oppomobile.com","ad.vivo.com.cn","ad.oneplus.com",
  "ad.alimama.com","ad.taobaocdn.com","ad.mmstat.com",
  "ad.crwdmna.com","ad.wrating.com","ad.linezing.com",
  "ad.dxpmedia.com","ad.adtchrome.com","ad.rekmob.com",
  "ad.startappservice.com","ad.tapad.com","ad.velti.com",
  "ad.media.net","ad.contextweb.com","ad.deepintent.com",
  "api.adnet.miui.com","api.ad.miui.com","ad.api.miui.com",
  "adv.sec.miui.com","adsrv.miui.com","adservice.miui.com",
  "adtrack.miui.com","adconfig.miui.com","adpush.miui.com",
};

const int adDomainCount = sizeof(adDomains) / sizeof(adDomains[0]);

// 域名匹配（支持子域名匹配）
bool isAdDomain(const char* domain) {
  for (int i = 0; i < adDomainCount; i++) {
    const char* ad = adDomains[i];
    int adLen = strlen(ad);
    int domLen = strlen(domain);
    if (domLen >= adLen) {
      if (strncmp(domain + (domLen - adLen), ad, adLen) == 0) {
        return true;
      }
    }
    if (strcmp(domain, ad) == 0) {
      return true;
    }
  }
  return false;
}

// 解析DNS请求中的域名
void parseDomain(uint8_t* buf, int len, char* domain, int maxLen) {
  int pos = 12;
  int di = 0;
  
  while (pos < len && buf[pos] != 0 && di < maxLen - 1) {
    int labelLen = buf[pos];
    pos++;
    for (int i = 0; i < labelLen && pos < len && di < maxLen - 1; i++) {
      domain[di++] = buf[pos++];
    }
    domain[di++] = '.';
  }
  if (di > 0 && domain[di-1] == '.') di--;
  domain[di] = '\0';
}

// 处理DNS查询
void handleDNS() {
  int len = dnsUdp.parsePacket();
  if (len <= 0) return;
  
  dnsUdp.read(dnsBuffer, len);
  dnsLen = len;
  
  char domain[256];
  parseDomain(dnsBuffer, len, domain, sizeof(domain));
  
  Serial.print("DNS查询: ");
  Serial.println(domain);
  
  if (isAdDomain(domain)) {
    Serial.println("  → 已拦截 (Sinkhole)");
    
    uint8_t response[512];
    memcpy(response, dnsBuffer, 12);
    response[2] = 0x81;
    response[3] = 0x80;
    response[6] = 0x00; response[7] = 0x01;
    response[8] = 0x00; response[9] = 0x01;
    
    int pos = 12;
    while (dnsBuffer[pos] != 0) {
      response[pos] = dnsBuffer[pos];
      pos++;
    }
    response[pos++] = 0;
    response[pos++] = 0; response[pos++] = 1;
    response[pos++] = 0; response[pos++] = 1;
    
    response[pos++] = 0xC0; response[pos++] = 0x0C;
    response[pos++] = 0x00; response[pos++] = 1;
    response[pos++] = 0x00; response[pos++] = 1;
    response[pos++] = 0x00; response[pos++] = 0x00;
    response[pos++] = 0x00; response[pos++] = 0x3C;
    response[pos++] = 0x00; response[pos++] = 0x04;
    response[pos++] = 0x00; response[pos++] = 0x00;
    response[pos++] = 0x00; response[pos++] = 0x00;
    
    dnsUdp.beginPacket(dnsUdp.remoteIP(), dnsUdp.remotePort());
    dnsUdp.write(response, pos);
    dnsUdp.endPacket();
    
  } else {
    Serial.println("  → 转发到上游DNS");
    
    WiFiUDP upstreamUdp;
    upstreamUdp.beginPacket(UPSTREAM_DNS, UPSTREAM_PORT);
    upstreamUdp.write(dnsBuffer, dnsLen);
    upstreamUdp.endPacket();
    
    unsigned long start = millis();
    int respLen = 0;
    uint8_t respBuf[512];
    
    while (millis() - start < 5000) {
      if (upstreamUdp.parsePacket()) {
        respLen = upstreamUdp.read(respBuf, 512);
        break;
      }
    }
    
    if (respLen > 0) {
      dnsUdp.beginPacket(dnsUdp.remoteIP(), dnsUdp.remotePort());
      dnsUdp.write(respBuf, respLen);
      dnsUdp.endPacket();
      Serial.print("  → 已转发，响应");
      Serial.print(respLen);
      Serial.println("字节");
    } else {
      Serial.println("  → 上游DNS无响应");
    }
  }
}

void handleRoot() {
  String html = "<!DOCTYPE html><html><head><meta charset='UTF-8'>";
  html += "<meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<title>ESP32 DNS AdBlock</title>";
  html += "<style>body{font-family:sans-serif;margin:20px;background:#f5f5f5}";
  html += "form{background:#fff;padding:20px;border-radius:8px;max-width:400px;margin:0 auto}";
  html += "input{width:100%;padding:10px;margin:5px 0;border:1px solid #ddd;border-radius:4px}";
  html += "button{width:100%;padding:12px;background:#4CAF50;color:#fff;border:none;border-radius:4px;cursor:pointer}";
  html += "button:hover{background:#45a049}</style></head><body>";
  html += "<form action='/save' method='POST'>";
  html += "<h2>ESP32 DNS AdBlock 配网</h2>";
  html += "<label>WiFi名称:</label><br><input name='ssid' placeholder='输入WiFi名称'><br>";
  html += "<label>WiFi密码:</label><br><input type='password' name='pass' placeholder='输入WiFi密码'><br><br>";
  html += "<button type='submit'>保存并连接</button>";
  html += "<p style='text-align:center'><a href='/status'>查看状态</a></p>";
  html += "</form></body></html>";
  webServer.send(200, "text/html", html);
}

void handleSave() {
  String ssid = webServer.arg("ssid");
  String pass = webServer.arg("pass");
  
  if (ssid.length() > 0) {
    writeEEPROM(0, 32, ssid);
    writeEEPROM(32, 64, pass);
    
    String html = "<!DOCTYPE html><html><head><meta charset='UTF-8'>";
    html += "<meta http-equiv='refresh' content='3;url=/'>";
    html += "<title>保存成功</title></head><body>";
    html += "<h2>保存成功！正在重启...</h2>";
    html += "<p>设备将尝试连接WiFi: " + ssid + "</p>";
    html += "</body></html>";
    webServer.send(200, "text/html", html);
    
    delay(1000);
    ESP.restart();
  } else {
    webServer.send(400, "text/plain", "WiFi名称不能为空");
  }
}

void handleStatus() {
  String html = "<!DOCTYPE html><html><head><meta charset='UTF-8'>";
  html += "<title>状态</title></head><body>";
  html += "<h2>ESP32 DNS AdBlock 状态</h2>";
  html += "<p>WiFi状态: " + String(WiFi.status() == WL_CONNECTED ? "已连接" : "未连接") + "</p>";
  if (WiFi.status() == WL_CONNECTED) {
    html += "<p>IP地址: " + WiFi.localIP().toString() + "</p>";
    html += "<p>上游DNS: " + String(UPSTREAM_DNS) + "</p>";
    html += "<p>黑名单域名数: " + String(adDomainCount) + "</p>";
  } else {
    html += "<p>AP模式: " + String(AP_SSID) + "</p>";
  }
  html += "<p><a href='/'>返回配网</a></p>";
  html += "</body></html>";
  webServer.send(200, "text/html", html);
}

String readEEPROM(int offset, int maxLen) {
  String result = "";
  for (int i = 0; i < maxLen; i++) {
    char c = char(EEPROM.read(offset + i));
    if (c == 0) break;
    result += c;
  }
  return result;
}

void writeEEPROM(int offset, int maxLen, String value) {
  for (int i = 0; i < maxLen; i++) {
    if (i < value.length()) {
      EEPROM.write(offset + i, value[i]);
    } else {
      EEPROM.write(offset + i, 0);
    }
  }
  EEPROM.commit();
}

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32-C3 DNS AdBlock v2 ===");
  
  EEPROM.begin(512);
  
  String savedSsid = readEEPROM(0, 32);
  String savedPass = readEEPROM(32, 64);
  
  if (savedSsid.length() > 0) {
    Serial.println("尝试连接已保存的WiFi: " + savedSsid);
    WiFi.begin(savedSsid.c_str(), savedPass.c_str());
    
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
      delay(500);
      attempts++;
      Serial.print(".");
    }
    Serial.println();
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    wifiConfigured = true;
    Serial.println("WiFi已连接! IP: " + WiFi.localIP().toString());
    
    dnsUdp.begin(DNS_PORT);
    Serial.println("DNS服务器已启动，端口53");
    Serial.print("上游DNS: ");
    Serial.println(UPSTREAM_DNS);
  } else {
    Serial.println("WiFi连接失败，启动AP配网模式");
    WiFi.mode(WIFI_AP_STA);
    WiFi.softAP(AP_SSID, AP_PASS);
    Serial.println("AP已启动: " + String(AP_SSID));
    Serial.println("请连接该WiFi，然后访问 192.168.4.1 配置");
  }
  
  webServer.on("/", handleRoot);
  webServer.on("/save", handleSave);
  webServer.on("/status", handleStatus);
  webServer.begin();
}

void loop() {
  webServer.handleClient();
  
  if (WiFi.status() == WL_CONNECTED) {
    handleDNS();
  }
  
  if (millis() - lastCheck > 30000) {
    lastCheck = millis();
    if (wifiConfigured && WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi断开，尝试重连...");
      WiFi.reconnect();
    }
  }
}

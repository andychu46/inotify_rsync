# inotify_rsync代码同步shell脚本

#### 介绍
以inotify+rsync同步discuz论坛代码shell脚本示例

#### 软件架构
需要安装inotify,rsync
并配置好目标主机的rsync项目

#### 优势
限制每秒同步一次，不会批量上传文件后进行海量同步。

#### 安装部署
```
mkdir -p /opt/shell/rsynclog && cd /opt/shell/  
#wget -O inotify.sh https://gitee.com/c1g/inotify_rsync/raw/master/inotify.sh   
wget -O inotify.sh https://github.com/andychu46/inotify_rsync/raw/main/inotify.sh
chmod +x ./inotify.sh
./inotify.sh &
```

#### 使用说明

 默认代码目录在 /opt/htdocs/discuz/  
 监听 {V_WATCH} 和 {V_WATCH2} 目录, 每秒只传输一次  
 注意：{V_RSYNC_DELETE}请谨慎操作,会删除不一致文件  
 如需半自动同步那就从监听中移除 {V_WATCH}  
 手动同步 
```
 touch ${V_WATCH2}/syncbbs
```
 开机启动
 ```
 echo "cd /opt/shell && /opt/shell/inotify.sh &" >> /etc/rc.local
```
 运行  
```
 cd /opt/shell && /opt/shell/inotify.sh &
```
 关闭可以直接杀  
```
 pkill inotify
```


#### 参与贡献

1.  Fork 本仓库
2.  新建 Feat_xxx 分支
3.  提交代码
4.  新建 Pull Request




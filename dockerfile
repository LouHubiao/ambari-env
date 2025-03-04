# 使用 CentOS 7.9 作为基础镜像  
FROM centos:7.9.2009  

# 设置容器的工作目录  
WORKDIR /  

# 将配置文件和数据挂载点创建 
VOLUME /scripts 
VOLUME /opt/modules/conf  
VOLUME /root/.m2  
VOLUME /data/rpm-package  

# 设置容器启动时的入口脚本  
ENTRYPOINT ["tail", "-f", "/dev/null"]  
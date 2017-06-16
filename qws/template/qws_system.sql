/*
Navicat MySQL Data Transfer

Source Server         : 192.168.1.49
Source Server Version : 50616
Source Host           : 192.168.1.49:3306
Source Database       : qws_system

Target Server Type    : MYSQL
Target Server Version : 50616
File Encoding         : 65001

Date: 2017-05-18 16:31:34
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for router
-- ----------------------------
DROP TABLE IF EXISTS `router`;
CREATE TABLE `router` (
  `router_id` char(36) NOT NULL,
  `upstream_id` char(36) NOT NULL COMMENT 'upstream_id',
  `server_id` text COMMENT '转发下游服务器列表',
  `rule` text COMMENT 'header定向规则，规则采用json存储',
  `uri` varchar(20) NOT NULL DEFAULT '' COMMENT '网关原URI路径',
  `new_uri` varchar(20) NOT NULL COMMENT '上游服务器目标URI路径',
  `created_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_forbidden` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否禁用，0为启用，1为禁用',
  PRIMARY KEY (`router_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='URL路由';

-- ----------------------------
-- Table structure for upstream
-- ----------------------------
DROP TABLE IF EXISTS `upstream`;
CREATE TABLE `upstream` (
  `upstream_id` char(36) NOT NULL,
  `name` varchar(255) DEFAULT NULL COMMENT '服务名称',
  `scheme` enum('https','http') NOT NULL DEFAULT 'http',
  `host` varchar(50) NOT NULL COMMENT 'CNAME指向网关的域名',
  `lb` tinyint(1) NOT NULL DEFAULT '0' COMMENT '负载均衡模式，0为随机，1为权重轮询,2为ip_hash,3为url_hash',
  `keepalive` int(2) NOT NULL DEFAULT '60' COMMENT 'upstream保持连接时长',
  `connect_timeout` int(11) NOT NULL DEFAULT '60000' COMMENT 'upstream内各服务连接超时时间，单位毫秒',
  `send_timeout` int(11) NOT NULL DEFAULT '60000' COMMENT '网关发送数据到上游服务器的超时时间，单位毫秒',
  `read_timeout` int(11) NOT NULL DEFAULT '60000' COMMENT '网关读取上游服务器数据的超时时间，单位毫秒',
  `created_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_forbidden` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否禁用，0为启用，1为禁用',
  PRIMARY KEY (`upstream_id`),
  UNIQUE KEY `host` (`host`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='upstream配置';

-- ----------------------------
-- Table structure for upstream_server
-- ----------------------------
DROP TABLE IF EXISTS `upstream_server`;
CREATE TABLE `upstream_server` (
  `server_id` char(36) NOT NULL,
  `upstream_id` char(36) DEFAULT NULL COMMENT 'upstream_id',
  `server` varchar(50) NOT NULL COMMENT '上游服务器地址',
  `port` int(4) NOT NULL COMMENT '上游服务器端口',
  `weight` tinyint(1) NOT NULL DEFAULT '0' COMMENT '负载权重值',
  `fails` tinyint(1) NOT NULL DEFAULT '0' COMMENT '最大失败次数',
  `created_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `status` enum('0','1','2') DEFAULT '0' COMMENT '服务器状态,0为服务正常， 1为服务不可用 ，2为服务宕机',
  `is_forbidden` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否禁用，0为启用，1为禁用',
  PRIMARY KEY (`server_id`),
  KEY `upstream_id` (`upstream_id`),
  KEY `host` (`server`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='upstream加载的服务器列表';

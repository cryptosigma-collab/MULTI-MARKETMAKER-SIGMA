CREATE DATABASE  IF NOT EXISTS `multi_marketmaker_sigma` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `multi_marketmaker_sigma`;
-- MySQL dump 10.13  Distrib 8.0.44, for macos15 (arm64)
--
-- Host: localhost    Database: multi_marketmaker_sigma
-- ------------------------------------------------------
-- Server version	9.5.0

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
SET @MYSQLDUMP_TEMP_LOG_BIN = @@SESSION.SQL_LOG_BIN;
SET @@SESSION.SQL_LOG_BIN= 0;

--
-- GTID state at the beginning of the backup 
--

SET @@GLOBAL.GTID_PURGED=/*!80000 '+'*/ 'cc2454cc-ddff-11f0-a736-cda1bfda068c:1-751074';

--
-- Table structure for table `closed_orders`
--

DROP TABLE IF EXISTS `closed_orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `closed_orders` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `identifier` enum('ENTER','EXIT') NOT NULL,
  `txid` varchar(64) NOT NULL,
  `refid` varchar(64) DEFAULT NULL,
  `userref` int DEFAULT NULL,
  `cl_ord_id` varchar(64) DEFAULT NULL,
  `status` varchar(50) NOT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `opentm` decimal(20,6) DEFAULT NULL,
  `closetm` decimal(20,6) DEFAULT NULL,
  `starttm` decimal(20,6) DEFAULT NULL,
  `expiretm` decimal(20,6) DEFAULT NULL,
  `pair` varchar(50) DEFAULT NULL,
  `side` enum('buy','sell') DEFAULT NULL,
  `ordertype` varchar(50) DEFAULT NULL,
  `descr_price` decimal(30,12) DEFAULT NULL,
  `descr_price2` decimal(30,12) DEFAULT NULL,
  `leverage` varchar(50) DEFAULT NULL,
  `order_description` text,
  `close_description` text,
  `volume` decimal(30,12) DEFAULT NULL,
  `volume_exec` decimal(30,12) DEFAULT NULL,
  `cost` decimal(30,12) DEFAULT NULL,
  `fee` decimal(30,12) DEFAULT NULL,
  `avg_price` decimal(30,12) DEFAULT NULL,
  `stopprice` decimal(30,12) DEFAULT NULL,
  `limitprice` decimal(30,12) DEFAULT NULL,
  `trigger_type` varchar(50) DEFAULT NULL,
  `margin` tinyint(1) DEFAULT NULL,
  `misc` varchar(255) DEFAULT NULL,
  `oflags` varchar(255) DEFAULT NULL,
  `time_in_force` varchar(20) DEFAULT NULL,
  `trades_json` json DEFAULT NULL,
  `raw_json` json DEFAULT NULL,
  `inserted_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `source_enter_txid` varchar(64) DEFAULT NULL,
  `accumulated_quantity` decimal(30,12) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_closed_txid` (`txid`),
  KEY `idx_identifier` (`identifier`),
  KEY `idx_status` (`status`),
  KEY `idx_pair` (`pair`),
  KEY `idx_cl_ord_id` (`cl_ord_id`),
  KEY `idx_userref` (`userref`),
  KEY `idx_opentm` (`opentm`),
  KEY `idx_closetm` (`closetm`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
SET @@SESSION.SQL_LOG_BIN = @MYSQLDUMP_TEMP_LOG_BIN;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-07-13  8:40:37

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
-- Table structure for table `levels`
--

DROP TABLE IF EXISTS `levels`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `levels` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `asset_symbol` varchar(20) NOT NULL,
  `market` varchar(20) NOT NULL,
  `strategy_id` varchar(64) NOT NULL DEFAULT 'DEFAULT',
  `level_number` int NOT NULL,
  `level_key` decimal(20,10) NOT NULL,
  `lock_lower` decimal(20,10) DEFAULT NULL,
  `lock_upper` decimal(20,10) DEFAULT NULL,
  `enter_price` decimal(20,10) NOT NULL,
  `exit_price` decimal(20,10) DEFAULT NULL,
  `usd_amount` decimal(20,10) NOT NULL,
  `enter_quantity` decimal(20,10) DEFAULT NULL,
  `exit_quantity` decimal(20,10) DEFAULT NULL,
  `accumulated_quantity` decimal(20,10) DEFAULT NULL,
  `state` enum('READY','ENTER_OPEN','ENTER_FILLED','EXIT_OPEN','EXIT_FILLED','COMPLETE','CANCELED','ERROR') NOT NULL DEFAULT 'READY',
  `enter_txid` varchar(64) DEFAULT NULL,
  `exit_txid` varchar(64) DEFAULT NULL,
  `source_reference_price` decimal(20,10) DEFAULT NULL,
  `enter_created_at` datetime DEFAULT NULL,
  `enter_filled_at` datetime DEFAULT NULL,
  `exit_created_at` datetime DEFAULT NULL,
  `exit_filled_at` datetime DEFAULT NULL,
  `raw_enter_json` json DEFAULT NULL,
  `raw_exit_json` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_asset_state` (`asset_symbol`,`state`),
  KEY `idx_enter_txid` (`enter_txid`),
  KEY `idx_exit_txid` (`exit_txid`),
  KEY `idx_asset_strategy_level_key` (`asset_symbol`,`strategy_id`,`level_key`)
) ENGINE=InnoDB AUTO_INCREMENT=52 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
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

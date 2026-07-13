import sys
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QLabel,
    QHBoxLayout, QVBoxLayout, QSizePolicy, QScrollArea
)
from PySide6.QtGui import QPixmap
from PySide6.QtCore import Qt
from PySide6.QtWidgets import QPushButton, QDialog
from PySide6.QtCore import QTimer

from PySide6.QtWidgets import QComboBox, QLineEdit, QGridLayout
import mysql.connector

import json
import websocket
from PySide6.QtCore import QObject, Signal
from datetime import datetime
import time
import ssl

import os
import base64
import hashlib
import hmac
import urllib.parse
import requests
import threading

DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "",
    "database": "cryptosigma",
}

# ---- Provide your image paths here ----
LOGO_LEFT_PATH = sys.path[0] + "/Images/logo-cryptosigma.png"
LOGO_RIGHT_PATH = "/Users/cryptosigma/Downloads/menu_icon_2.png"

KRAKEN_API_KEY = “”
KRAKEN_API_SECRET = “”
KRAKEN_API_URL = "https://api.kraken.com"

# GLOBALS ############################################################################################################
ASSET = None
LAST = None
BEST_BID = None
BEST_ASK = None
DRY_RUN = True

# GUI ################################################################################################################
class LadderWidget(QWidget):
    def __init__(self, rows=100, parent=None):
        super().__init__(parent)

        self.rows = rows
        self.left_cells = []
        self.mid_cells = []
        self.right_cells = []

        self.setFixedWidth(260)
        self.setStyleSheet("background-color: #323232;")

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        for _ in range(rows):
            layout.addWidget(self._make_row())

        layout.addStretch(1)

    def _cell(self, text: str, bg_color: str, align: Qt.AlignmentFlag) -> QLabel:
        lab = QLabel(text)
        lab.setAlignment(align)
        lab.setFixedHeight(18)
        lab.setStyleSheet(f"""
            QLabel {{
                color: white;
                font-size: 11px;
                font-weight: 300;
                background-color: {bg_color};
                border: 0.5px solid white;
            }}
        """)
        return lab

    def _make_row(self) -> QWidget:
        row = QWidget()
        row.setFixedHeight(18)

        row_layout = QHBoxLayout(row)
        row_layout.setContentsMargins(0, 0, 0, 0)
        row_layout.setSpacing(0)

        blue = "#2563eb"
        gray = "#6b7280"
        red = "#dc2626"

        left = self._cell("", blue, Qt.AlignLeft | Qt.AlignVCenter)
        mid = self._cell("", gray, Qt.AlignCenter)
        right = self._cell("", red, Qt.AlignRight | Qt.AlignVCenter)

        self.left_cells.append(left)
        self.mid_cells.append(mid)
        self.right_cells.append(right)

        row_layout.addWidget(left, 1)
        row_layout.addWidget(mid, 1)
        row_layout.addWidget(right, 1)

        return row

    def update_ask_ladder(self, best_ask: float, exit_orders=None):
        """
        ASK ladder:
        - Bottom row = best ask
        - Each row above = +1%
        - Red column shows EXIT orders at closest price level
        """

        if not best_ask:
            return

        exit_orders = exit_orders or []

        # ==========================
        # CLEAR EXISTING DATA
        # ==========================
        for row_index in range(self.rows):
            self.left_cells[row_index].setText("")
            self.right_cells[row_index].setText("")

        # ==========================
        # BUILD PRICE LADDER
        # ==========================
        row_prices = []

        for row_index in range(self.rows):
            # bottom row is best ask
            steps_above_best_ask = (self.rows - 1) - row_index

            row_price = best_ask * (
                    1 + (steps_above_best_ask * 0.0025)
            )

            row_prices.append(row_price)

            # middle gray column
            self.mid_cells[row_index].setText(
                f"{row_price:,.2f}"
            )

        # ==========================
        # PLACE EXIT ORDERS
        # ==========================
        for order in exit_orders:
            exit_price = float(order["price"])
            exit_volume = float(order["volume"])

            # find closest price row
            closest_row = min(
                range(self.rows),
                key=lambda i: abs(row_prices[i] - exit_price)
            )

            # if multiple exits land here, add them
            existing = self.right_cells[closest_row].text()

            existing_volume = (
                float(existing)
                if existing
                else 0
            )

            total_volume = existing_volume + exit_volume

            # red column
            self.right_cells[closest_row].setText(
                f"{total_volume:.8f}"
            )

    def update_bid_ladder(self, best_bid: float, enter_orders=None):
        """
        BID ladder:
        - Top row = best bid
        - Each row below = -0.05%
        - Blue/left column shows ENTER orders at closest price level
        """

        if not best_bid:
            return

        enter_orders = enter_orders or []

        # clear side cells
        for row_index in range(self.rows):
            self.left_cells[row_index].setText("")
            self.right_cells[row_index].setText("")

        # build bid ladder prices
        row_prices = []

        for row_index in range(self.rows):
            steps_below_best_bid = row_index

            row_price = best_bid * (
                    1 - (steps_below_best_bid * 0.0025)
            )

            row_prices.append(row_price)

            self.mid_cells[row_index].setText(
                f"{row_price:,.2f}"
            )

        # place ENTER orders on closest row
        for order in enter_orders:
            enter_price = float(order["price"])
            enter_volume = float(order["volume"])

            closest_row = min(
                range(self.rows),
                key=lambda i: abs(row_prices[i] - enter_price)
            )

            existing = self.left_cells[closest_row].text()

            existing_volume = (
                float(existing)
                if existing
                else 0
            )

            total_volume = existing_volume + enter_volume

            # blue column
            self.left_cells[closest_row].setText(
                f"{total_volume:.8f}"
            )

class PricingTable(QWidget):
    """
    Single-row pricing table:
    - same thin white borders
    - 3 columns
    - backgrounds: white / gray / white
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedWidth(260)
        self.setStyleSheet("background-color: #323232;")

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        layout.addWidget(self._make_row())

    def _cell(self, text: str, bg_color: str, fg_color: str, align: Qt.AlignmentFlag) -> QLabel:
        lab = QLabel(text)
        lab.setAlignment(align)
        lab.setFixedHeight(18)
        lab.setStyleSheet(f"""
            QLabel {{
                color: {fg_color};
                font-size: 11px;
                font-weight: 400;
                background-color: {bg_color};
                border: 0.5px solid white;
            }}
        """)
        return lab

    def _make_row(self) -> QWidget:
        row = QWidget()
        row.setFixedHeight(18)

        row_layout = QHBoxLayout(row)
        row_layout.setContentsMargins(0, 0, 0, 0)
        row_layout.setSpacing(0)

        bg_white = "#ffffff"
        bg_gray = "#6b7280"

        fg_black = "#000000"
        fg_white = "#ffffff"

        c1 = self._cell("", bg_white, fg_black, Qt.AlignLeft | Qt.AlignVCenter)
        self.price_label = self._cell("0.000000", bg_gray, fg_white, Qt.AlignCenter)
        c2 = self.price_label
        c3 = self._cell("", bg_white, fg_black, Qt.AlignRight | Qt.AlignVCenter)

        row_layout.addWidget(c1, 1)
        row_layout.addWidget(c2, 1)
        row_layout.addWidget(c3, 1)

        return row

    def set_price(self, price):
        self.price_label.setText(f"{price:,.2f}")

class MenuWindow(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Menu")
        self.setFixedSize(260, 240)
        self.setStyleSheet("""
            QDialog {
                background-color: #323232;
            }
            QLabel {
                color: white;
                font-size: 11px;
                font-weight: 300;
            }
            QComboBox, QLineEdit {
                background-color: black;
                color: white;
                border: 0.5px solid white;
                padding: 3px;
                font-size: 11px;
            }
        """)

        layout = QGridLayout(self)
        layout.setContentsMargins(15, 15, 15, 15)
        layout.setHorizontalSpacing(10)
        layout.setVerticalSpacing(10)

        asset_label = QLabel("Asset")
        self.asset_dropdown = QComboBox()
        self.asset_dropdown.addItems(self.fetch_assets())

        levels_label = QLabel("Levels")
        self.levels_input = QLineEdit()
        self.levels_input.setPlaceholderText("10")

        range_label = QLabel("Range")
        self.range_input = QLineEdit()
        self.range_input.setPlaceholderText("Percent")

        scalp_label = QLabel("Scalp")
        self.scalp_input = QLineEdit()
        self.scalp_input.setPlaceholderText("Percent")

        amount_label = QLabel("Amount")
        self.amount_input = QLineEdit()
        self.amount_input.setPlaceholderText("USD total")

        self.start_button = QPushButton("START")
        self.start_button.setCursor(Qt.PointingHandCursor)
        self.start_button.setStyleSheet("""
            QPushButton {
                background-color: #0c5e76;
                color: white;
                border: none;
                padding: 5px;
                font-size: 11px;
                font-weight: 400;
            }
            QPushButton:hover {
                background-color: #117a99;
            }
        """)

        layout.addWidget(asset_label, 0, 0)
        layout.addWidget(self.asset_dropdown, 0, 1)

        layout.addWidget(levels_label, 1, 0)
        layout.addWidget(self.levels_input, 1, 1)

        layout.addWidget(range_label, 2, 0)
        layout.addWidget(self.range_input, 2, 1)

        layout.addWidget(scalp_label, 3, 0)
        layout.addWidget(self.scalp_input, 3, 1)

        layout.addWidget(amount_label, 4, 0)
        layout.addWidget(self.amount_input, 4, 1)

        layout.addWidget(self.start_button, 5, 0, 1, 2)

    def fetch_assets(self):
        self.asset_market_map = {}

        try:
            conn = mysql.connector.connect(**DB_CONFIG)
            cur = conn.cursor()
            cur.execute("SELECT symbol, market FROM multi_marketmaker_sigma.assets ORDER BY id")

            symbols = []
            for symbol, market in cur.fetchall():
                symbols.append(symbol)
                self.asset_market_map[symbol] = market

            cur.close()
            conn.close()
            return symbols

        except Exception as e:
            print("Failed to fetch assets:", e)
            return []

class MarketMakerSignals(QObject):
    price_update = Signal(float, float, float, float, float, float, float, str)
    net_update = Signal(float)
    exit_orders_update = Signal(list)
    enter_orders_update = Signal(list)
    accumulation_update = Signal(float)

class MarketMakerDB:
    def __init__(self):
        pass

    def connect(self):
        return mysql.connector.connect(**DB_CONFIG)

    def fetch_open_orders(self, asset_symbol):
        conn = self.connect()
        cur = conn.cursor(dictionary=True)

        cur.execute("""
            SELECT *
            FROM multi_marketmaker_sigma.open_orders
            WHERE asset_symbol = %s
              AND status = 'open'
            ORDER BY created_at
        """, (asset_symbol,))

        rows = cur.fetchall()
        cur.close()
        conn.close()
        return rows

    def fetch_enter_orders(self, asset_symbol):
        conn = self.connect()
        cur = conn.cursor(dictionary=True)

        cur.execute("""
            SELECT price, volume, txid, reference_price, reprice_trigger
            FROM multi_marketmaker_sigma.open_orders
            WHERE asset_symbol = %s
              AND identifier = 'ENTER'
              AND status = 'open'
              AND price IS NOT NULL
            ORDER BY created_at
        """, (asset_symbol,))

        rows = cur.fetchall()
        cur.close()
        conn.close()
        return rows

    def fetch_exit_orders(self, asset_symbol):
        conn = self.connect()
        cur = conn.cursor(dictionary=True)

        cur.execute("""
            SELECT price, volume, txid
            FROM multi_marketmaker_sigma.open_orders
            WHERE asset_symbol = %s
              AND identifier = 'EXIT'
              AND status = 'open'
              AND price IS NOT NULL
            ORDER BY created_at
        """, (asset_symbol,))

        rows = cur.fetchall()
        cur.close()
        conn.close()
        return rows

    def fetch_net_exit_volume(self, asset_symbol):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            SELECT COALESCE(SUM(volume), 0)
            FROM multi_marketmaker_sigma.open_orders
            WHERE asset_symbol = %s
              AND identifier = 'EXIT'
              AND status = 'open'
        """, (asset_symbol,))

        net = float(cur.fetchone()[0])
        cur.close()
        conn.close()
        return net

    def insert_open_order(self, order):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            INSERT INTO multi_marketmaker_sigma.open_orders
            (
                identifier,
                asset_symbol,
                market,
                side,
                ordertype,
                volume,
                price,
                reference_price,
                reprice_trigger,
                txid,
                order_description,
                status,
                source_enter_txid,
                accumulated_quantity
            )
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            order["identifier"],
            order["asset_symbol"],
            order["market"],
            order["side"],
            order["ordertype"],
            order["volume"],
            order["price"],
            order.get("reference_price"),
            order.get("reprice_trigger"),
            order["txid"],
            order["order_description"],
            order.get("status", "open"),
            order.get("source_enter_txid"),
            order.get("accumulated_quantity")
        ))

        conn.commit()
        cur.close()
        conn.close()

    def delete_open_order(self, txid):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            DELETE FROM multi_marketmaker_sigma.open_orders
            WHERE txid = %s
        """, (txid,))

        conn.commit()
        cur.close()
        conn.close()

    def update_open_order_status(self, txid, status):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            UPDATE multi_marketmaker_sigma.open_orders
            SET status = %s
            WHERE txid = %s
        """, (status, txid))

        conn.commit()
        cur.close()
        conn.close()

    def move_open_to_canceled(self, txid, cancel_reason):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            INSERT INTO multi_marketmaker_sigma.canceled_orders
            (
                identifier,
                asset_symbol,
                market,
                side,
                ordertype,
                volume,
                price,
                reference_price,
                reprice_trigger,
                txid,
                order_description,
                status,
                cancel_reason,
                created_at
            )
            SELECT
                identifier,
                asset_symbol,
                market,
                side,
                ordertype,
                volume,
                price,
                reference_price,
                reprice_trigger,
                txid,
                order_description,
                status,
                %s,
                created_at
            FROM multi_marketmaker_sigma.open_orders
            WHERE txid=%s
        """, (cancel_reason, txid))

        cur.execute("""
            DELETE
            FROM multi_marketmaker_sigma.open_orders
            WHERE txid=%s
        """, (txid,))

        conn.commit()
        cur.close()
        conn.close()

    def insert_partial_order(self, partial):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            INSERT INTO multi_marketmaker_sigma.partial_orders
            (
                txid,
                identifier,
                asset_symbol,
                market,
                original_volume,
                filled_volume,
                remaining_volume,
                original_usd_size,
                filled_usd,
                remaining_usd,
                order_price,
                reference_price,
                reprice_trigger,
                status,
                raw_json
            )
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            partial["txid"],
            partial["identifier"],
            partial["asset_symbol"],
            partial["market"],
            partial.get("original_volume"),
            partial.get("filled_volume"),
            partial.get("remaining_volume"),
            partial.get("original_usd_size"),
            partial.get("filled_usd"),
            partial.get("remaining_usd"),
            partial.get("order_price"),
            partial.get("reference_price"),
            partial.get("reprice_trigger"),
            partial.get("status", "partial"),
            json.dumps(partial.get("raw_json", {}))
        ))

        conn.commit()
        cur.close()
        conn.close()

    def fetch_partial_orders(self, asset_symbol):
        conn = self.connect()
        cur = conn.cursor(dictionary=True)

        cur.execute("""
            SELECT *
            FROM multi_marketmaker_sigma.partial_orders
            WHERE asset_symbol = %s
              AND status = 'partial'
            ORDER BY created_at
        """, (asset_symbol,))

        rows = cur.fetchall()

        cur.close()
        conn.close()

        return rows

    def update_partial_order(self, txid, filled_volume, remaining_volume, filled_usd, remaining_usd):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            UPDATE multi_marketmaker_sigma.partial_orders
            SET
                filled_volume = %s,
                remaining_volume = %s,
                filled_usd = %s,
                remaining_usd = %s
            WHERE txid = %s
        """, (
            filled_volume,
            remaining_volume,
            filled_usd,
            remaining_usd,
            txid
        ))

        conn.commit()
        cur.close()
        conn.close()

    def close_partial_order(self, txid):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            UPDATE multi_marketmaker_sigma.partial_orders
            SET status = 'closed'
            WHERE txid = %s
        """, (txid,))

        conn.commit()
        cur.close()
        conn.close()

    def fetch_open_order_by_txid(self, txid):
        conn = self.connect()
        cur = conn.cursor(dictionary=True)

        cur.execute("""
            SELECT *
            FROM multi_marketmaker_sigma.open_orders
            WHERE txid = %s
        """, (txid,))

        row = cur.fetchone()

        cur.close()
        conn.close()
        return row

    def move_open_to_closed(self, txid, close_reason="KRAKEN_FILLED"):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            INSERT INTO multi_marketmaker_sigma.closed_orders
            (
                identifier,
                txid,
                status,
                reason,
                pair,
                side,
                ordertype,
                volume,
                volume_exec,
                avg_price,
                order_description,
                source_enter_txid,
                accumulated_quantity,
                raw_json
            )
            SELECT
                identifier,
                txid,
                'closed',
                %s,
                market,
                side,
                ordertype,
                volume,
                volume,
                price,
                order_description,
                source_enter_txid,
                accumulated_quantity,
                JSON_OBJECT(
                    'source', 'multi_marketmaker_sigma',
                    'txid', txid,
                    'identifier', identifier,
                    'price', price,
                    'volume', volume,
                    'source_enter_txid', source_enter_txid,
                    'accumulated_quantity', accumulated_quantity
                )
            FROM multi_marketmaker_sigma.open_orders
            WHERE txid = %s
        """, (close_reason, txid))

        cur.execute("""
            DELETE FROM multi_marketmaker_sigma.open_orders
            WHERE txid = %s
        """, (txid,))

        conn.commit()
        cur.close()
        conn.close()

    def fetch_coin_accumulation(self, asset_symbol, market):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            SELECT COALESCE(SUM(accumulated_quantity), 0)
            FROM (
                SELECT accumulated_quantity
                FROM multi_marketmaker_sigma.open_orders
                WHERE asset_symbol = %s
                  AND identifier = 'EXIT'
                  AND accumulated_quantity IS NOT NULL

                UNION ALL

                SELECT accumulated_quantity
                FROM multi_marketmaker_sigma.closed_orders
                WHERE pair = %s
                  AND identifier = 'EXIT'
                  AND accumulated_quantity IS NOT NULL
            ) x
        """, (asset_symbol, market))

        total = float(cur.fetchone()[0])

        cur.close()
        conn.close()

        return total

    def fetch_locked_level_keys(self, asset_symbol):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            SELECT level_key
            FROM multi_marketmaker_sigma.levels
            WHERE asset_symbol = %s
              AND state IN (
                  'ENTER_OPEN',
                  'ENTER_FILLED',
                  'EXIT_OPEN'
              )
        """, (asset_symbol,))

        rows = [float(r[0]) for r in cur.fetchall()]

        cur.close()
        conn.close()

        return rows

    def insert_level(self, level):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            INSERT INTO multi_marketmaker_sigma.levels
            (
                asset_symbol,
                market,
                strategy_id,
                level_number,
                level_key,
                lock_lower,
                lock_upper,
                enter_price,
                exit_price,
                usd_amount,
                enter_quantity,
                exit_quantity,
                accumulated_quantity,
                state,
                enter_txid,
                exit_txid,
                source_reference_price,
                enter_created_at,
                raw_enter_json
            )
            VALUES
            (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,NOW(),%s)
        """, (
            level["asset_symbol"],
            level["market"],
            level.get("strategy_id", "DEFAULT"),
            level["level_number"],
            level["level_key"],
            level.get("lock_lower"),
            level.get("lock_upper"),
            level["enter_price"],
            level.get("exit_price"),
            level["usd_amount"],
            level.get("enter_quantity"),
            level.get("exit_quantity"),
            level.get("accumulated_quantity"),
            level["state"],
            level.get("enter_txid"),
            level.get("exit_txid"),
            level.get("source_reference_price"),
            json.dumps(level.get("raw_enter_json", {}))
        ))

        conn.commit()
        cur.close()
        conn.close()

    def fetch_level_by_enter_txid(self, txid):
        conn = self.connect()
        cur = conn.cursor(dictionary=True)

        cur.execute("""
            SELECT *
            FROM multi_marketmaker_sigma.levels
            WHERE enter_txid = %s
            LIMIT 1
        """, (txid,))

        row = cur.fetchone()

        cur.close()
        conn.close()

        return row

    def fetch_level_by_exit_txid(self, txid):
        conn = self.connect()
        cur = conn.cursor(dictionary=True)

        cur.execute("""
            SELECT *
            FROM multi_marketmaker_sigma.levels
            WHERE exit_txid = %s
            LIMIT 1
        """, (txid,))

        row = cur.fetchone()

        cur.close()
        conn.close()

        return row

    def mark_level_enter_filled(self, enter_txid, fill_price):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            UPDATE multi_marketmaker_sigma.levels
            SET
                state = 'ENTER_FILLED',
                enter_filled_at = NOW(),
                enter_price = %s
            WHERE enter_txid = %s
        """, (fill_price, enter_txid))

        conn.commit()
        cur.close()
        conn.close()

    def mark_level_exit_open(self, enter_txid, exit_txid, exit_price, exit_quantity, accumulated_quantity,
                             raw_exit_json=None):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            UPDATE multi_marketmaker_sigma.levels
            SET
                state = 'EXIT_OPEN',
                exit_txid = %s,
                exit_price = %s,
                exit_quantity = %s,
                accumulated_quantity = %s,
                exit_created_at = NOW(),
                raw_exit_json = %s
            WHERE enter_txid = %s
        """, (
            exit_txid,
            exit_price,
            exit_quantity,
            accumulated_quantity,
            json.dumps(raw_exit_json or {}),
            enter_txid
        ))

        conn.commit()
        cur.close()
        conn.close()

    def mark_level_exit_filled(self, exit_txid):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            UPDATE multi_marketmaker_sigma.levels
            SET
                state = 'EXIT_FILLED',
                exit_filled_at = NOW()
            WHERE exit_txid = %s
        """, (exit_txid,))

        conn.commit()
        cur.close()
        conn.close()

    def fetch_active_levels(self, asset_symbol):
        conn = self.connect()
        cur = conn.cursor(dictionary=True)

        cur.execute("""
            SELECT *
            FROM multi_marketmaker_sigma.levels
            WHERE asset_symbol = %s
              AND state IN (
                  'ENTER_OPEN',
                  'ENTER_FILLED',
                  'EXIT_OPEN'
              )
            ORDER BY level_key DESC
        """, (asset_symbol,))

        rows = cur.fetchall()

        cur.close()
        conn.close()

        return rows

    def fetch_enter_open_levels(self, asset_symbol):
        conn = self.connect()
        cur = conn.cursor(dictionary=True)

        cur.execute("""
            SELECT *
            FROM multi_marketmaker_sigma.levels
            WHERE asset_symbol = %s
              AND state = 'ENTER_OPEN'
            ORDER BY level_key ASC
        """, (asset_symbol,))

        rows = cur.fetchall()
        cur.close()
        conn.close()
        return rows

    def mark_level_canceled_by_enter_txid(self, enter_txid):
        conn = self.connect()
        cur = conn.cursor()

        cur.execute("""
            UPDATE multi_marketmaker_sigma.levels
            SET state = 'CANCELED'
            WHERE enter_txid = %s
        """, (enter_txid,))

        conn.commit()
        cur.close()
        conn.close()

    def mark_level_canceled_by_enter_txids(self, enter_txids):
        if not enter_txids:
            return

        conn = self.connect()
        cur = conn.cursor()

        placeholders = ",".join(["%s"] * len(enter_txids))

        cur.execute(f"""
            UPDATE multi_marketmaker_sigma.levels
            SET state = 'CANCELED'
            WHERE enter_txid IN ({placeholders})
        """, enter_txids)

        conn.commit()
        cur.close()
        conn.close()

    def fetch_locked_ranges(self, asset_symbol):
        conn = self.connect()
        cur = conn.cursor(dictionary=True)

        cur.execute("""
            SELECT
                id,
                level_key,
                lock_lower,
                lock_upper,
                state,
                enter_txid,
                exit_txid
            FROM multi_marketmaker_sigma.levels
            WHERE asset_symbol = %s
              AND state IN (
                  'ENTER_FILLED',
                  'EXIT_OPEN'
              )
              AND lock_lower IS NOT NULL
              AND lock_upper IS NOT NULL
            ORDER BY lock_lower
        """, (asset_symbol,))

        rows = cur.fetchall()

        cur.close()
        conn.close()

        return rows

class KrakenRestClient:
    BASE_URL = "https://api.kraken.com"

    def __init__(self, dry_run=True):
        self.dry_run = dry_run
        self.api_key = KRAKEN_API_KEY
        self.api_secret = KRAKEN_API_SECRET
        self.nonce_lock = threading.Lock()
        self.last_nonce = 0

    def _nonce(self):
        with self.nonce_lock:
            nonce = int(time.time() * 1000)

            if nonce <= self.last_nonce:
                nonce = self.last_nonce + 1

            self.last_nonce = nonce
            return str(nonce)

    def _sign(self, url_path, data):
        post_data = urllib.parse.urlencode(data)
        encoded = (str(data["nonce"]) + post_data).encode()

        message = url_path.encode() + hashlib.sha256(encoded).digest()

        signature = hmac.new(
            base64.b64decode(self.api_secret),
            message,
            hashlib.sha512
        )

        return base64.b64encode(signature.digest()).decode()

    def private_request(self, endpoint, data=None):
        if data is None:
            data = {}

        url_path = f"/0/private/{endpoint}"
        url = self.BASE_URL + url_path

        data["nonce"] = self._nonce()

        headers = {
            "API-Key": self.api_key,
            "API-Sign": self._sign(url_path, data),
            "User-Agent": "MARKETMAKER-SIGMA"
        }

        response = requests.post(
            url,
            headers=headers,
            data=data,
            timeout=15
        )

        response.raise_for_status()
        result = response.json()

        if result.get("error") and any("Invalid nonce" in e for e in result["error"]):
            time.sleep(0.25)

            data["nonce"] = self._nonce()

            headers["API-Sign"] = self._sign(url_path, data)

            response = requests.post(
                url,
                headers=headers,
                data=data,
                timeout=15
            )

            response.raise_for_status()
            result = response.json()

        return result

    def add_order(self, pair, side, ordertype, volume, price, identifier):
        payload = {
            "pair": pair,
            "type": side,
            "ordertype": ordertype,
            "volume": f"{volume:.8f}",
            "price": f"{price:.1f}",
        }

        if self.dry_run:
            print("DRY RUN ADD ORDER:", identifier, payload)
            return {
                "txid": f"DRY_{identifier}_{int(time.time() * 1000)}",
                "descr": {
                    "order": (
                        f"{side} {volume:.8f} {pair} "
                        f"@ {ordertype} {price:.2f}"
                    )
                },
                "raw": {
                    "dry_run": True,
                    "payload": payload
                }
            }

        result = self.private_request("AddOrder", payload)

        if result.get("error"):
            raise Exception(f"Kraken AddOrder error: {result['error']}")

        return {
            "txid": result["result"]["txid"][0],
            "descr": result["result"]["descr"],
            "raw": result
        }

    def cancel_order(self, txid):
        payload = {
            "txid": txid
        }

        if self.dry_run:
            print("DRY RUN CANCEL ORDER:", txid)
            return {
                "txid": txid,
                "raw": {
                    "dry_run": True,
                    "canceled": True
                }
            }

        result = self.private_request("CancelOrder", payload)

        if result.get("error"):
            raise Exception(f"Kraken CancelOrder error: {result['error']}")

        return {
            "txid": txid,
            "raw": result
        }

    def get_websocket_token(self):
        result = self.private_request("GetWebSocketsToken", {})

        if result.get("error"):
            raise Exception(f"Kraken token error: {result['error']}")

        return result["result"]["token"]

    def query_orders(self, txids):
        if not txids:
            return {}

        payload = {
            "txid": ",".join(txids),
            "trades": True
        }

        result = self.private_request("QueryOrders", payload)

        if result.get("error"):
            raise Exception(f"Kraken QueryOrders error: {result['error']}")

        return result.get("result", {})

class MarketMakerEngine:
    def __init__(self):
        self.running = False
        self.asset = None
        self.market = None
        self.levels = None
        self.range_pct = None
        self.scalp_pct = None
        self.total_amount = None
        self.level_amount = None
        self.step_pct = None
        self.ladder_anchor_price = None
        self.signals = MarketMakerSignals()
        self.ws = None
        self.db = MarketMakerDB()
        self.kraken = KrakenRestClient(dry_run=DRY_RUN)
        self.private_ws = None
        self.startup_recalibration_pending = True

    def start(self, asset, market, levels, range_pct, scalp_pct, total_amount):
        self.running = True
        self.asset = asset
        self.market = market

        self.levels = levels
        self.range_pct = range_pct
        self.scalp_pct = scalp_pct
        self.total_amount = total_amount
        self.startup_recalibration_pending = True
        self.ladder_anchor_price = None

        self.level_amount = total_amount / levels
        self.step_pct = range_pct / levels

        print("MULTI MARKET MAKER STARTED")
        print("Asset:", self.asset)
        print("Market:", self.market)
        print("Levels:", self.levels)
        print("Range %:", self.range_pct)
        print("Step %:", self.step_pct)
        print("Scalp %:", self.scalp_pct)
        print("Total Amount:", self.total_amount)
        print("Level Amount:", self.level_amount)

        self.start_public_ticker_ws()
        self.start_private_executions_ws()
        self.reconcile_open_orders_with_kraken()
        self.refresh_net()
        self.refresh_exit_orders()
        self.refresh_enter_orders()
        self.refresh_accumulation()

    def start_public_ticker_ws(self):
        symbol = f"{self.asset}/USD"

        def on_open(ws):
            print("Ticker websocket opened:", symbol)

            subscribe_msg = {
                "method": "subscribe",
                "params": {
                    "channel": "ticker",
                    "symbol": [symbol],
                    "event_trigger": "bbo",
                    "snapshot": True
                }
            }

            ws.send(json.dumps(subscribe_msg))

        def on_message(ws, message):
            global LAST, BEST_BID, BEST_ASK

            try:
                msg = json.loads(message)
            except Exception as e:
                print("Ticker JSON error:", e)
                return

            if msg.get("channel") != "ticker":
                return

            data = msg.get("data", [])

            if not data:
                return

            tick = data[0]

            LAST = float(tick.get("last", 0))
            BEST_BID = float(tick.get("bid", 0))
            BEST_ASK = float(tick.get("ask", 0))

            ts = tick.get(
                "timestamp",
                datetime.now().isoformat()
            )

            # print(
            #     "LAST:", LAST,
            #     "BID:", BEST_BID,
            #     "ASK:", BEST_ASK
            # )

            high = float(tick.get("high", 0))
            low = float(tick.get("low", 0))
            change = float(tick.get("change_pct", 0))
            volume = float(tick.get("volume", 0))

            self.signals.price_update.emit(
                LAST,
                BEST_BID,
                BEST_ASK,
                high,
                low,
                change,
                volume,
                ts
            )

            self.process_market_tick(LAST, BEST_BID, BEST_ASK)

        def on_error(ws, error):
            print("Ticker websocket error:", error)

        def on_close(ws, close_status_code, close_msg):
            print(
                "Ticker websocket closed:",
                close_status_code,
                close_msg
            )

        def run_ws_loop():
            reconnect_delay = 2

            while self.running:

                try:
                    print("Starting ticker websocket...")

                    self.ws = websocket.WebSocketApp(
                        "wss://ws.kraken.com/v2",
                        on_open=on_open,
                        on_message=on_message,
                        on_error=on_error,
                        on_close=on_close
                    )

                    self.ws.run_forever(
                        sslopt={"cert_reqs": ssl.CERT_NONE},
                        ping_interval=0
                    )

                except Exception as e:
                    print(
                        "Ticker websocket loop error:",
                        e
                    )

                if self.running:
                    print(
                        f"Ticker websocket reconnecting in {reconnect_delay} seconds..."
                    )

                    time.sleep(reconnect_delay)

                    reconnect_delay = min(
                        reconnect_delay * 2,
                        30
                    )

        import threading
        import time

        t = threading.Thread(
            target=run_ws_loop,
            daemon=True
        )

        t.start()

    def refresh_net(self):
        try:
            net = self.db.fetch_net_exit_volume(self.asset)
            self.signals.net_update.emit(net)

        except Exception as e:
            print("Failed to refresh Net:", e)
            self.signals.net_update.emit(0.0)

    def refresh_exit_orders(self):
        try:
            rows = self.db.fetch_exit_orders(self.asset)
            self.signals.exit_orders_update.emit(rows)

        except Exception as e:
            print("Failed to refresh EXIT orders:", e)
            self.signals.exit_orders_update.emit([])

    def refresh_enter_orders(self):
        try:
            rows = self.db.fetch_enter_orders(self.asset)
            self.signals.enter_orders_update.emit(rows)

        except Exception as e:
            print("Failed to refresh ENTER orders:", e)
            self.signals.enter_orders_update.emit([])

    def place_enter_order(self, reference_price):
        scalp = self.scalp_pct / 100

        enter_price = reference_price * (1 - scalp)
        reprice_trigger = reference_price * (1 + scalp)

        # self.level_amount is USD size
        quantity = self.level_amount / enter_price

        result = self.kraken.add_order(
            pair=self.market,
            side="buy",
            ordertype="limit",
            volume=quantity,
            price=enter_price,
            identifier="ENTER"
        )

        txid = result["txid"]

        order = {
            "identifier": "ENTER",
            "asset_symbol": self.asset,
            "market": self.market,
            "side": "buy",
            "ordertype": "limit",
            "volume": quantity,
            "price": enter_price,
            "reference_price": reference_price,
            "reprice_trigger": reprice_trigger,
            "source_enter_txid": None,
            "accumulated_quantity": None,
            "txid": txid,
            "order_description": result["descr"]["order"],
            "status": "open"
        }

        self.db.insert_open_order(order)

        print("ENTER PLACED:", order)

        self.refresh_enter_orders()
        self.refresh_exit_orders()
        self.refresh_net()
        self.refresh_accumulation()

    def place_exit_order(self, enter_order):
        scalp = self.scalp_pct / 100

        enter_price = float(enter_order["price"])
        exit_price = enter_price * (1 + scalp)

        # EXIT sells only original USD size worth at the exit price
        level = self.db.fetch_level_by_enter_txid(enter_order["txid"])

        usd_amount = (
            float(level["usd_amount"])
            if level and level.get("usd_amount") is not None
            else self.level_amount
        )

        exit_quantity = usd_amount / exit_price

        enter_quantity = float(enter_order["volume"])
        accumulated_quantity = enter_quantity - exit_quantity

        result = self.kraken.add_order(
            pair=self.market,
            side="sell",
            ordertype="limit",
            volume=exit_quantity,
            price=exit_price,
            identifier="EXIT"
        )

        txid = result["txid"]

        order = {
            "identifier": "EXIT",
            "asset_symbol": self.asset,
            "market": self.market,
            "side": "sell",
            "ordertype": "limit",
            "volume": exit_quantity,
            "price": exit_price,
            "reference_price": enter_price,
            "reprice_trigger": None,
            "source_enter_txid": enter_order["txid"],
            "accumulated_quantity": accumulated_quantity,
            "txid": txid,
            "order_description": result["descr"]["order"],
            "status": "open"
        }

        self.db.insert_open_order(order)

        self.db.mark_level_exit_open(
            enter_txid=enter_order["txid"],
            exit_txid=txid,
            exit_price=exit_price,
            exit_quantity=exit_quantity,
            accumulated_quantity=accumulated_quantity,
            raw_exit_json=result.get("raw", {})
        )

        print("EXIT PLACED:", order)
        print("ACCUMULATED COIN:", accumulated_quantity)

        self.refresh_enter_orders()
        self.refresh_exit_orders()
        self.refresh_net()
        self.refresh_accumulation()

    def simulate_enter_fill(self, txid):
        enter_order = self.db.fetch_open_order_by_txid(txid)

        if not enter_order:
            print("No open order found for txid:", txid)
            return

        if enter_order["identifier"] != "ENTER":
            print("Order is not ENTER. Skipping:", txid)
            return

        print("SIMULATING ENTER FILL:", txid)

        self.db.move_open_to_closed(
            txid=txid,
            close_reason="SIM_ENTER_FILLED"
        )

        self.place_exit_order(enter_order)

        if LAST:
            self.ensure_enter_ladder(LAST)

        self.refresh_enter_orders()
        self.refresh_exit_orders()
        self.refresh_net()

    def ensure_one_enter_order(self, current_price):
        enter_orders = self.db.fetch_enter_orders(self.asset)

        # No ENTER order exists, place one
        if len(enter_orders) == 0:
            print("No ENTER order found. Placing new simulated ENTER.")
            self.place_enter_order(current_price)
            return

        # There should only be one ENTER order
        if len(enter_orders) > 1:
            print("WARNING: More than one ENTER order found.")
            return

        # Exactly one ENTER order exists
        enter = enter_orders[0]

        reprice_trigger = enter.get("reprice_trigger")

        if reprice_trigger is None:
            print("ENTER order has no reprice_trigger. Skipping reprice check.")
            return

        reprice_trigger = float(reprice_trigger)

        # print(
        #     "ENTER working:",
        #     enter["txid"],
        #     "price:",
        #     enter["price"],
        #     "trigger:",
        #     reprice_trigger,
        #     "current:",
        #     current_price
        # )

        # If market moved up enough, cancel/reprice simulated ENTER
        if current_price >= reprice_trigger:
            print("REPRICE TRIGGER HIT. Canceling old ENTER and placing new one.")

            cancel_result = self.kraken.cancel_order(
                txid=enter["txid"]
            )

            self.db.move_open_to_canceled(
                txid=enter["txid"],
                cancel_reason="REPRICE"
            )

            print("ENTER CANCELED:", cancel_result)

            self.place_enter_order(current_price)

            self.refresh_enter_orders()
            self.refresh_exit_orders()
            self.refresh_net()

    def process_price_simulated_fills(self, current_price):
        """
        Uses public ticker price to simulate one fill per websocket tick.

        ENTER fills when market price <= enter limit price.
        EXIT fills when market price >= exit limit price.
        """

        open_orders = self.db.fetch_open_orders(self.asset)

        for order in open_orders:
            txid = order["txid"]
            identifier = order["identifier"]
            order_price = float(order["price"])

            # ==========================
            # SIMULATE ENTER FILL
            # ==========================
            if identifier == "ENTER" and current_price <= order_price:
                print("SIM ENTER FILLED:", txid, "at", order_price)

                self.db.move_open_to_closed(
                    txid=txid,
                    close_reason="SIM_ENTER_FILLED_BY_PRICE"
                )

                self.db.mark_level_enter_filled(
                    enter_txid=txid,
                    fill_price=order_price
                )

                self.place_exit_order(order)

                # Strategy decides if another ENTER is needed
                self.ensure_enter_ladder(current_price)

                self.refresh_enter_orders()
                self.refresh_exit_orders()
                self.refresh_net()
                self.refresh_accumulation()

                return

            # ==========================
            # SIMULATE EXIT FILL
            # ==========================
            elif identifier == "EXIT" and current_price >= order_price:
                print("SIM EXIT FILLED:", txid, "at", order_price)

                self.db.move_open_to_closed(
                    txid=txid,
                    close_reason="SIM_EXIT_FILLED_BY_PRICE"
                )

                self.db.mark_level_exit_filled(
                    exit_txid=txid
                )

                self.lift_one_enter_after_exit_fill(current_price)

                self.refresh_enter_orders()
                self.refresh_exit_orders()
                self.refresh_net()
                self.refresh_accumulation()

                return

        # No fills occurred this tick
        self.refresh_enter_orders()
        self.refresh_exit_orders()
        self.refresh_net()
        self.refresh_accumulation()

    def refresh_accumulation(self):
        try:
            total = self.db.fetch_coin_accumulation(self.asset, self.market)
            self.signals.accumulation_update.emit(total)
        except Exception as e:
            print("Failed to refresh accumulation:", e)
            self.signals.accumulation_update.emit(0.0)

    def process_market_tick(self, last, bid, ask):
        """
        Main strategy decision point.
        Called once per websocket ticker update.
        """

        startup_recalibrated = self.recalibrate_ladder_on_start(
            current_price=last
        )

        if not startup_recalibrated:
            repriced = self.reprice_ladder_up(last)

            self.ensure_enter_ladder(
                current_price=last,
                rebuild_from_anchor=repriced
            )

        if self.kraken.dry_run:
            self.process_price_simulated_fills(last)

        self.refresh_enter_orders()
        self.refresh_exit_orders()
        self.refresh_net()
        self.refresh_accumulation()

    def stop(self):
        print("STOPPING MARKET MAKER")

        self.running = False

        # Close public ticker websocket
        if self.ws:
            try:
                self.ws.close()
            except Exception as e:
                print("Error closing websocket:", e)

        # Close private executions websocket
        if self.private_ws:
            try:
                self.private_ws.close()
            except Exception as e:
                print("Error closing private websocket:", e)

        print("MARKET MAKER STOPPED")

    def start_private_executions_ws(self):
        token = self.kraken.get_websocket_token()

        def on_open(ws):
            print("Private executions websocket opened")

            subscribe_msg = {
                "method": "subscribe",
                "params": {
                    "channel": "executions",
                    "token": token,
                    "snap_orders": True,
                    "snap_trades": False,
                    "order_status": True
                }
            }

            ws.send(json.dumps(subscribe_msg))

        def on_message(ws, message):
            try:
                msg = json.loads(message)
            except Exception as e:
                print("Private WS JSON error:", e)
                return

            if msg.get("method") == "subscribe":
                print("PRIVATE EXECUTIONS SUBSCRIBED:", msg)
                self.reconcile_open_orders_with_kraken()
                return

            if msg.get("channel") != "executions":
                return

            msg_type = msg.get("type")
            data = msg.get("data", [])

            for event in data:
                exec_type = event.get("exec_type")
                order_status = event.get("order_status")
                order_id = event.get("order_id")

                print(
                    "EXECUTION EVENT:",
                    "type=", msg_type,
                    "exec_type=", exec_type,
                    "status=", order_status,
                    "order_id=", order_id
                )

                self.handle_execution_event(event)

        def on_error(ws, error):
            print("Private executions websocket error:", error)

        def on_close(ws, close_status_code, close_msg):
            print("Private executions websocket closed:", close_status_code, close_msg)

        def run_private_ws_loop():
            reconnect_delay = 2

            while self.running:
                try:
                    token = self.kraken.get_websocket_token()

                    self.private_ws = websocket.WebSocketApp(
                        "wss://ws-auth.kraken.com/v2",
                        on_open=on_open,
                        on_message=on_message,
                        on_error=on_error,
                        on_close=on_close
                    )

                    self.private_ws.run_forever(
                        sslopt={"cert_reqs": ssl.CERT_NONE},
                        ping_interval=20,
                        ping_timeout=10
                    )

                except Exception as e:
                    print("Private executions websocket loop error:", e)

                if self.running:
                    print(f"Private executions websocket reconnecting in {reconnect_delay} seconds...")
                    time.sleep(reconnect_delay)
                    reconnect_delay = min(reconnect_delay * 2, 30)

        t = threading.Thread(target=run_private_ws_loop, daemon=True)
        t.start()

    def handle_execution_event(self, event):
        exec_type = event.get("exec_type")
        order_status = event.get("order_status")
        txid = event.get("order_id")

        if not txid:
            return

        open_order = self.db.fetch_open_order_by_txid(txid)

        # Ignore Kraken events not created/tracked by this strategy
        if not open_order:
            return

        print("HANDLING STRATEGY EXECUTION:", exec_type, order_status, txid)

        # Ignore live/open/status confirmations for now
        if exec_type in ("pending_new", "new", "status"):
            return

        # Full fill
        if order_status == "filled" or exec_type == "filled":
            self.db.move_open_to_closed(
                txid=txid,
                close_reason="KRAKEN_FILLED"
            )

            if open_order["identifier"] == "ENTER":
                self.db.mark_level_enter_filled(
                    enter_txid=txid,
                    fill_price=float(open_order["price"])
                )

                self.place_exit_order(open_order)

                if LAST:
                    self.ensure_enter_ladder(LAST)



            elif open_order["identifier"] == "EXIT":

                self.db.mark_level_exit_filled(

                    exit_txid=txid

                )

                if LAST:
                    self.lift_one_enter_after_exit_fill(

                        current_price=LAST

                    )

            self.refresh_enter_orders()
            self.refresh_exit_orders()
            self.refresh_net()
            self.refresh_accumulation()
            return

        # Partial fill
        if exec_type == "trade" and order_status == "partially_filled":
            print("PARTIAL FILL DETECTED:", event)
            return

        # Canceled
        if exec_type == "canceled" or order_status == "canceled":
            self.db.move_open_to_canceled(
                txid=txid,
                cancel_reason=event.get("reason", "KRAKEN_CANCELED")
            )

            self.refresh_enter_orders()
            self.refresh_exit_orders()
            self.refresh_net()
            self.refresh_accumulation()
            return

    def reconcile_open_orders_with_kraken(self):
        print("Reconciling open orders with Kraken...")

        open_orders = self.db.fetch_open_orders(self.asset)

        if not open_orders:
            print("No local open orders to reconcile.")
            return

        if self.kraken.dry_run:
            print("DRY RUN: skipping Kraken reconciliation.")
            return

        txids = [o["txid"] for o in open_orders]

        try:
            kraken_orders = self.kraken.query_orders(txids)
        except Exception as e:
            print("Failed to query Kraken orders:", e)
            return

        for order in open_orders:
            txid = order["txid"]
            k = kraken_orders.get(txid)

            if not k:
                print("Kraken did not return txid:", txid)
                continue

            status = k.get("status")
            print("RECONCILE:", txid, status)

            if status == "closed":
                self.db.move_open_to_closed(
                    txid=txid,
                    close_reason="KRAKEN_RECONCILED_CLOSED"
                )

                if order["identifier"] == "ENTER":
                    self.place_exit_order(order)

            elif status == "canceled":
                self.db.move_open_to_canceled(
                    txid=txid,
                    cancel_reason="KRAKEN_RECONCILED_CANCELED"
                )

        self.refresh_enter_orders()
        self.refresh_exit_orders()
        self.refresh_net()
        self.refresh_accumulation()

    def ensure_enter_ladder(
            self,
            current_price,
            rebuild_from_anchor=False
    ):
        """
        Maintains the configured number of working ENTER orders.

        rebuild_from_anchor=True:
            A full upward reprice occurred.
            Build a fresh ladder starting below the new anchor.

        rebuild_from_anchor=False:
            Normal maintenance after an ENTER fill.
            Add replacement ENTER orders below the lowest active level.

        Locked EXIT ranges are skipped.
        """

        if not current_price:
            return

        if self.ladder_anchor_price is None:
            self.ladder_anchor_price = current_price

        # Current active level rows:
        # ENTER_OPEN, ENTER_FILLED, EXIT_OPEN
        active_levels = self.db.fetch_active_levels(self.asset)

        enter_open_levels = [
            level
            for level in active_levels
            if level["state"] == "ENTER_OPEN"
        ]

        working_enter_count = len(enter_open_levels)
        missing_levels = self.levels - working_enter_count

        if missing_levels <= 0:
            return

        # Wider ranges locked by filled ENTER levels and active EXITs.
        locked_ranges = self.db.fetch_locked_ranges(self.asset)

        # Exact prices currently occupied by working ENTER orders.
        existing_enter_prices = [
            float(level["level_key"])
            for level in enter_open_levels
        ]

        # ---------------------------------------------------------
        # SELECT WHERE LADDER GENERATION STARTS
        # ---------------------------------------------------------
        if rebuild_from_anchor:
            # Full upward reprice:
            # begin again at position 1 beneath the new anchor.
            candidate_level_number = 1

        else:
            # Normal fill:
            # continue below the deepest active level.
            active_level_numbers = [
                int(level["level_number"])
                for level in active_levels
                if level.get("level_number") is not None
            ]

            if active_level_numbers:
                candidate_level_number = max(active_level_numbers) + 1
            else:
                candidate_level_number = 1

        levels_created = 0
        attempts = 0

        # Allows room to skip locked ranges without creating an endless loop.
        maximum_attempts = max(
            self.levels * 20,
            100
        )

        while (
                levels_created < missing_levels
                and attempts < maximum_attempts
        ):
            attempts += 1

            level_prices = self.calculate_level_prices(
                anchor_price=self.ladder_anchor_price,
                level_number=candidate_level_number
            )

            enter_price = float(level_prices["enter_price"])
            lock_lower = float(level_prices["lock_lower"])
            lock_upper = float(level_prices["lock_upper"])

            level_key = round(enter_price, 10)

            # Save this position before moving to the next candidate.
            level_number = candidate_level_number
            candidate_level_number += 1

            # -----------------------------------------------------
            # DO NOT DUPLICATE AN EXISTING WORKING ENTER
            # -----------------------------------------------------
            exact_price_exists = any(
                abs(level_key - existing_price) < 0.00000001
                for existing_price in existing_enter_prices
            )

            if exact_price_exists:
                print(
                    "ENTER PRICE ALREADY OPEN, SKIPPING:",
                    level_key
                )
                continue

            # -----------------------------------------------------
            # DO NOT ENTER INSIDE A LOCKED RANGE
            # Boundaries remain allowed.
            # -----------------------------------------------------
            if self.is_price_inside_locked_range(
                    proposed_price=enter_price,
                    locked_ranges=locked_ranges
            ):
                print(
                    "LOCKED RANGE SKIPPED:",
                    "level_number=", level_number,
                    "price=", enter_price
                )
                continue

            # -----------------------------------------------------
            # PLACE ENTER ORDER
            # -----------------------------------------------------
            quantity = self.level_amount / enter_price

            result = self.kraken.add_order(
                pair=self.market,
                side="buy",
                ordertype="limit",
                volume=quantity,
                price=enter_price,
                identifier="ENTER"
            )

            txid = result["txid"]

            order = {
                "identifier": "ENTER",
                "asset_symbol": self.asset,
                "market": self.market,
                "side": "buy",
                "ordertype": "limit",
                "volume": quantity,
                "price": enter_price,
                "reference_price": self.ladder_anchor_price,
                "reprice_trigger": None,
                "source_enter_txid": None,
                "accumulated_quantity": None,
                "txid": txid,
                "order_description": result["descr"]["order"],
                "status": "open"
            }

            self.db.insert_open_order(order)

            level = {
                "asset_symbol": self.asset,
                "market": self.market,
                "strategy_id": "DEFAULT",
                "level_number": level_number,
                "level_key": level_key,
                "lock_lower": lock_lower,
                "lock_upper": lock_upper,
                "enter_price": enter_price,
                "exit_price": None,
                "usd_amount": self.level_amount,
                "enter_quantity": quantity,
                "exit_quantity": None,
                "accumulated_quantity": None,
                "state": "ENTER_OPEN",
                "enter_txid": txid,
                "exit_txid": None,
                "source_reference_price": self.ladder_anchor_price,
                "raw_enter_json": result.get("raw", {})
            }

            self.db.insert_level(level)

            existing_enter_prices.append(level_key)
            levels_created += 1

            print(
                "LEVEL ENTER PLACED:",
                "level_number=", level_number,
                "price=", enter_price,
                "lock_lower=", lock_lower,
                "lock_upper=", lock_upper,
                "txid=", txid
            )

        if levels_created < missing_levels:
            print(
                "WARNING: Could not create all missing ENTER levels.",
                "needed=", missing_levels,
                "created=", levels_created,
                "attempts=", attempts
            )

        if levels_created:
            self.refresh_enter_orders()
            self.refresh_exit_orders()
            self.refresh_net()
            self.refresh_accumulation()

    def reprice_ladder_up(self, current_price):
        if not current_price:
            return False

        enter_open_levels = self.db.fetch_enter_open_levels(self.asset)

        if not enter_open_levels:
            return False

        step = self.step_pct / 100

        if self.ladder_anchor_price is None:
            self.ladder_anchor_price = current_price
            return False

        reprice_trigger = self.ladder_anchor_price * (1 + step)

        if current_price < reprice_trigger:
            return False

        print(
            "FULL LADDER REPRICE UP:",
            "current_price=", current_price,
            "trigger=", reprice_trigger
        )

        enter_txids = []

        for level in enter_open_levels:
            txid = level["enter_txid"]

            cancel_result = self.kraken.cancel_order(txid=txid)

            self.db.move_open_to_canceled(
                txid=txid,
                cancel_reason="FULL_REPRICE_UP"
            )

            enter_txids.append(txid)

            print(
                "REPRICE CANCELED:",
                level["level_key"],
                cancel_result
            )

        self.db.mark_level_canceled_by_enter_txids(
            enter_txids
        )

        self.ladder_anchor_price = current_price

        self.refresh_enter_orders()
        self.refresh_exit_orders()
        self.refresh_net()
        self.refresh_accumulation()

        return True

    def is_price_inside_locked_range(self, proposed_price, locked_ranges):
        proposed_price = float(proposed_price)

        for locked in locked_ranges:
            lower = float(locked["lock_lower"])
            upper = float(locked["lock_upper"])

            # Open interval:
            # lower and upper boundaries are allowed.
            if lower < proposed_price < upper:
                print(
                    "PRICE INSIDE LOCKED RANGE:",
                    proposed_price,
                    "range:",
                    lower,
                    "to",
                    upper
                )
                return True

        return False

    def calculate_level_prices(self, anchor_price, level_number):
        """
        Returns the price and neighboring lock boundaries for one ladder level.

        Example with anchor=100 and step=1%:

            level 1:
                upper = 100
                price = 99
                lower = 98.01

        The exact upper and lower boundaries remain allowed.
        Only prices strictly between them are locked after the ENTER fills.
        """

        step = self.step_pct / 100

        upper_price = anchor_price * (
                (1 - step) ** (level_number - 1)
        )

        enter_price = anchor_price * (
                (1 - step) ** level_number
        )

        lower_price = anchor_price * (
                (1 - step) ** (level_number + 1)
        )

        return {
            "enter_price": enter_price,
            "lock_lower": lower_price,
            "lock_upper": upper_price
        }

    def lift_one_enter_after_exit_fill(self, current_price):
        """
        After an EXIT fills, move one working ENTER upward.

        Cancels the lowest ENTER_OPEN order and replaces it with the
        highest valid grid price beneath the current ladder anchor,
        skipping active locked ranges and existing ENTER prices.
        """

        if not current_price:
            return

        if self.ladder_anchor_price is None:
            self.ladder_anchor_price = current_price

        enter_open_levels = self.db.fetch_enter_open_levels(self.asset)

        if not enter_open_levels:
            self.ensure_enter_ladder(
                current_price=current_price,
                rebuild_from_anchor=True
            )
            return

        locked_ranges = self.db.fetch_locked_ranges(self.asset)

        existing_enter_prices = [
            float(level["level_key"])
            for level in enter_open_levels
        ]

        lowest_open_level = min(
            enter_open_levels,
            key=lambda level: float(level["level_key"])
        )

        lowest_open_price = float(lowest_open_level["level_key"])

        replacement = None

        maximum_attempts = max(self.levels * 20, 100)

        for level_number in range(1, maximum_attempts + 1):
            prices = self.calculate_level_prices(
                anchor_price=self.ladder_anchor_price,
                level_number=level_number
            )

            candidate_price = float(prices["enter_price"])
            candidate_key = round(candidate_price, 10)

            # We only want to improve the ladder.
            if candidate_price <= lowest_open_price:
                break

            exact_price_exists = any(
                abs(candidate_key - existing_price) < 0.00000001
                for existing_price in existing_enter_prices
            )

            if exact_price_exists:
                continue

            if self.is_price_inside_locked_range(
                    proposed_price=candidate_price,
                    locked_ranges=locked_ranges
            ):
                continue

            replacement = {
                "level_number": level_number,
                "enter_price": candidate_price,
                "level_key": candidate_key,
                "lock_lower": float(prices["lock_lower"]),
                "lock_upper": float(prices["lock_upper"])
            }

            break

        if replacement is None:
            print(
                "EXIT FILLED: no higher unlocked ENTER position available.",
                "lowest_open=", lowest_open_price
            )
            return

        old_txid = lowest_open_level["enter_txid"]

        print(
            "EXIT FILL LADDER LIFT:",
            "cancel lowest=", lowest_open_price,
            "new enter=", replacement["enter_price"]
        )

        cancel_result = self.kraken.cancel_order(
            txid=old_txid
        )

        self.db.move_open_to_canceled(
            txid=old_txid,
            cancel_reason="EXIT_FILL_LADDER_LIFT"
        )

        self.db.mark_level_canceled_by_enter_txid(
            enter_txid=old_txid
        )

        enter_price = replacement["enter_price"]
        quantity = self.level_amount / enter_price

        result = self.kraken.add_order(
            pair=self.market,
            side="buy",
            ordertype="limit",
            volume=quantity,
            price=enter_price,
            identifier="ENTER"
        )

        txid = result["txid"]

        order = {
            "identifier": "ENTER",
            "asset_symbol": self.asset,
            "market": self.market,
            "side": "buy",
            "ordertype": "limit",
            "volume": quantity,
            "price": enter_price,
            "reference_price": self.ladder_anchor_price,
            "reprice_trigger": None,
            "source_enter_txid": None,
            "accumulated_quantity": None,
            "txid": txid,
            "order_description": result["descr"]["order"],
            "status": "open"
        }

        self.db.insert_open_order(order)

        level = {
            "asset_symbol": self.asset,
            "market": self.market,
            "strategy_id": "DEFAULT",
            "level_number": replacement["level_number"],
            "level_key": replacement["level_key"],
            "lock_lower": replacement["lock_lower"],
            "lock_upper": replacement["lock_upper"],
            "enter_price": enter_price,
            "exit_price": None,
            "usd_amount": self.level_amount,
            "enter_quantity": quantity,
            "exit_quantity": None,
            "accumulated_quantity": None,
            "state": "ENTER_OPEN",
            "enter_txid": txid,
            "exit_txid": None,
            "source_reference_price": self.ladder_anchor_price,
            "raw_enter_json": result.get("raw", {})
        }

        self.db.insert_level(level)

        print(
            "EXIT FILL REPLACEMENT ENTER PLACED:",
            "price=", enter_price,
            "canceled=", old_txid,
            "new_txid=", txid,
            "cancel_result=", cancel_result
        )

        self.refresh_enter_orders()
        self.refresh_exit_orders()
        self.refresh_net()
        self.refresh_accumulation()

    def recalibrate_ladder_on_start(self, current_price):
        """
        On the first valid market tick after startup:

        1. Set the ladder anchor to the current market price.
        2. Cancel all existing ENTER_OPEN orders.
        3. Keep all EXIT_OPEN positions untouched.
        4. Rebuild 10 ENTER orders from the current anchor.
        5. Skip all currently locked ranges.
        """

        if not current_price:
            return False

        if not self.startup_recalibration_pending:
            return False

        print(
            "STARTUP LADDER RECALIBRATION:",
            "current_price=", current_price
        )

        self.ladder_anchor_price = current_price

        enter_open_levels = self.db.fetch_enter_open_levels(
            self.asset
        )

        enter_txids = []

        for level in enter_open_levels:
            txid = level["enter_txid"]

            cancel_result = self.kraken.cancel_order(
                txid=txid
            )

            self.db.move_open_to_canceled(
                txid=txid,
                cancel_reason="STARTUP_RECALIBRATION"
            )

            enter_txids.append(txid)

            print(
                "STARTUP RECALIBRATION CANCELED:",
                level["level_key"],
                cancel_result
            )

        if enter_txids:
            self.db.mark_level_canceled_by_enter_txids(
                enter_txids
            )

        self.startup_recalibration_pending = False

        self.ensure_enter_ladder(
            current_price=current_price,
            rebuild_from_anchor=True
        )

        return True

class MarketMakerWindow(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("")
        self.setMinimumSize(300, 550)

        self.exit_orders = []
        self.enter_orders = []

        # ===== Central Widget =====
        central = QWidget()
        central.setStyleSheet("background-color: #323232;")
        self.setCentralWidget(central)

        main_layout = QVBoxLayout(central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        self.engine = MarketMakerEngine()
        self.engine.signals.price_update.connect(self.on_price_update)
        self.engine.signals.net_update.connect(self.on_net_update)
        self.engine.signals.exit_orders_update.connect(self.on_exit_orders_update)
        self.engine.signals.enter_orders_update.connect(self.on_enter_orders_update)
        self.engine.signals.accumulation_update.connect(self.on_accumulation_update)

        # ===== TOP BAR (BLACK) =====
        top_bar_widget = QWidget()
        top_bar_widget.setFixedHeight(65)
        top_bar_widget.setStyleSheet("""
            background-color: black;
        """)

        top_bar_layout = QVBoxLayout(top_bar_widget)
        top_bar_layout.setContentsMargins(10, 6, 10, 6)
        top_bar_layout.setSpacing(0)

        # ===== ROW 1: LOGOS + VALUE =====
        row1 = QHBoxLayout()
        row1.setSpacing(0)

        # LEFT
        left_container = QWidget()
        left_layout = QHBoxLayout(left_container)
        left_layout.setContentsMargins(0, 0, 0, 0)

        self.logo_left = QLabel()
        self.logo_left.setPixmap(self._load_pixmap(LOGO_LEFT_PATH, 20))
        left_layout.addWidget(self.logo_left)

        # CENTER
        center_container = QWidget()
        center_layout = QHBoxLayout(center_container)
        center_layout.setContentsMargins(0, 0, 0, 0)
        center_layout.setAlignment(Qt.AlignCenter)

        self.value_label = QLabel("0.00")
        self.value_label.setStyleSheet("""
            QLabel {
                color: white;
                font-size: 13px;
                font-weight: 300;
                letter-spacing: 1px;
            }
        """)
        center_layout.addWidget(self.value_label)

        center_container.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)

        # RIGHT
        right_container = QWidget()
        right_layout = QHBoxLayout(right_container)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setAlignment(Qt.AlignRight | Qt.AlignVCenter)

        self.menu_button = QPushButton()
        self.menu_button.setIcon(self._load_pixmap(LOGO_RIGHT_PATH, 20))
        self.menu_button.setIconSize(self._load_pixmap(LOGO_RIGHT_PATH, 20).size())
        self.menu_button.setFixedSize(24, 24)  # keeps it tight
        self.menu_button.setCursor(Qt.PointingHandCursor)

        self.menu_button.setStyleSheet("""
            QPushButton {
                background-color: transparent;
                border: none;
            }
            QPushButton:hover {
                background-color: rgba(255, 255, 255, 0.05);
            }
        """)

        self.menu_button.clicked.connect(self.open_menu)

        right_layout.addWidget(self.menu_button)

        row1.addWidget(left_container)
        row1.addWidget(center_container)
        row1.addWidget(right_container)

        # ===== STATS ROWS =====
        stats_style = "QLabel { color: white; font-size: 11px; font-weight: 300; }"

        def make_stats_row(left_pair, right_pairs, key_w=10, val_w=40):
            w = QWidget()
            w.setStyleSheet("background-color: black;")
            l = QHBoxLayout(w)
            l.setContentsMargins(0, 0, 0, 0)
            l.setSpacing(8)

            # ----- LEFT GROUP -----
            left = QWidget()
            ll = QHBoxLayout(left)
            ll.setContentsMargins(0, 0, 0, 0)
            ll.setSpacing(6)

            for t in left_pair:
                lab = QLabel(t)
                lab.setStyleSheet(stats_style)

                if t == "0.00000000":
                    self.lbl_net = lab
                elif t == "0":
                    self.lbl_pl = lab

                ll.addWidget(lab)

            # ----- RIGHT GROUP -----
            right = QWidget()
            rl = QHBoxLayout(right)
            rl.setContentsMargins(0, 0, 0, 0)
            rl.setSpacing(6)
            rl.setAlignment(Qt.AlignRight | Qt.AlignVCenter)

            for i, t in enumerate(right_pairs):
                lab = QLabel(t)
                lab.setStyleSheet(stats_style)
                lab.setAlignment(Qt.AlignRight | Qt.AlignVCenter)

                # Even index = key (H:, O:), odd index = value (98,345, 97,234)
                if i % 2 == 0:
                    lab.setFixedWidth(key_w)
                else:
                    lab.setFixedWidth(val_w)

                rl.addWidget(lab)
                if t == "0" and i == 1 and right_pairs[0] == "H:":
                    self.lbl_high = lab
                elif t == "0" and i == 3 and right_pairs[2] == "C:":
                    self.lbl_change = lab
                elif t == "0" and i == 1 and right_pairs[0] == "L:":
                    self.lbl_low = lab
                elif t == "0" and i == 3 and right_pairs[2] == "V:":
                    self.lbl_volume = lab

            l.addWidget(left)
            l.addStretch(1)
            l.addWidget(right)
            return w

        self.lbl_net = None
        self.lbl_pl = None
        self.lbl_high = None
        self.lbl_change = None
        self.lbl_low = None
        self.lbl_volume = None

        top_bar_layout.addLayout(row1)
        stats_row_1 = make_stats_row(
            ["Net:", "0.00000000"],
            ["H:", "0", "C:", "0"],
            key_w=13,
            val_w=42
        )

        stats_row_2 = make_stats_row(
            ["P/L:", "0"],
            ["L:", "0", "V:", "0"],
            key_w=13,
            val_w=42
        )

        top_bar_layout.addWidget(stats_row_1)
        top_bar_layout.addWidget(stats_row_2)

        # ===== TABLES =====
        # Main ladder
        self.ask_ladder = LadderWidget(rows=100)
        ladder_scroll = QScrollArea()
        ladder_scroll.setWidget(self.ask_ladder)

        ladder_scroll.setWidgetResizable(True)
        ladder_scroll.setFixedSize(260, 200)
        ladder_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        ladder_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        ladder_scroll.setFrameShape(QScrollArea.NoFrame)
        ladder_scroll.setStyleSheet("background-color: #323232;")

        QTimer.singleShot(0, lambda: ladder_scroll.verticalScrollBar().setValue(
            ladder_scroll.verticalScrollBar().maximum()
        ))

        # Pricing table (1 row)
        self.pricing_table = PricingTable()

        # Best bid table (another 100-row ladder, same as first)
        self.best_bid_table = LadderWidget(rows=100)
        best_bid_scroll = QScrollArea()
        best_bid_scroll.setWidget(self.best_bid_table)
        best_bid_scroll.setWidgetResizable(True)
        best_bid_scroll.setFixedSize(260, 200)
        best_bid_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        best_bid_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        best_bid_scroll.setFrameShape(QScrollArea.NoFrame)
        best_bid_scroll.setStyleSheet("background-color: #323232;")

        # Center all tables and ensure NO spacing between them
        tables_stack = QVBoxLayout()
        tables_stack.setContentsMargins(0, 8, 0, 0)  # keep your gap under top bar
        tables_stack.setSpacing(0)  # IMPORTANT: no spacing between ladder + pricing + best_bid_table

        center_ladder = QHBoxLayout()
        center_ladder.setContentsMargins(0, 0, 0, 0)
        center_ladder.setSpacing(0)
        center_ladder.addStretch(1)
        center_ladder.addWidget(ladder_scroll)
        center_ladder.addStretch(1)

        center_pricing = QHBoxLayout()
        center_pricing.setContentsMargins(0, 0, 0, 0)
        center_pricing.setSpacing(0)
        center_pricing.addStretch(1)
        center_pricing.addWidget(self.pricing_table)
        center_pricing.addStretch(1)

        center_best_bid = QHBoxLayout()
        center_best_bid.setContentsMargins(0, 0, 0, 0)
        center_best_bid.setSpacing(0)
        center_best_bid.addStretch(1)
        center_best_bid.addWidget(best_bid_scroll)
        center_best_bid.addStretch(1)

        tables_stack.addLayout(center_ladder)
        tables_stack.addLayout(center_pricing)
        tables_stack.addLayout(center_best_bid)

        # ===== BOTTOM BAR (HEARTBEAT) =====
        bottom_bar_widget = QWidget()
        bottom_bar_widget.setFixedHeight(50)
        bottom_bar_widget.setStyleSheet("background-color: black;")

        bottom_layout = QHBoxLayout(bottom_bar_widget)
        bottom_layout.setContentsMargins(10, 0, 10, 0)

        self.heartbeat_label = QLabel("HEARTBEAT")
        self.heartbeat_label.setAlignment(Qt.AlignCenter)
        self.heartbeat_label.setStyleSheet("""
                    QLabel {
                        color: white;
                        font-size: 9px;
                        font-weight: 300;
                    }
                """)

        bottom_layout.addStretch(1)
        bottom_layout.addWidget(self.heartbeat_label)
        bottom_layout.addStretch(1)

        # ===== Assemble =====
        # ===== STOP BUTTON =====
        self.stop_button = QPushButton("STOP")
        self.stop_button.setCursor(Qt.PointingHandCursor)
        self.stop_button.setFixedHeight(30)
        self.stop_button.setStyleSheet("""
            QPushButton {
                background-color: #ff6b6b;
                color: white;
                border: none;
                border-radius: 4px;
                font-size: 14px;
                font-weight: 600;
            }
            QPushButton:hover {
                background-color: #ff4d4d;
            }
            QPushButton:pressed {
                background-color: #d93636;
            }
        """)

        self.stop_button.clicked.connect(self.stop_market_maker)

        # ===== STOP BAR =====
        stop_bar = QWidget()
        stop_bar.setStyleSheet("background-color: black;")

        stop_button_layout = QHBoxLayout(stop_bar)
        stop_button_layout.setContentsMargins(50, 6, 50, 16)
        stop_button_layout.addWidget(self.stop_button)

        # ===== Assemble =====
        main_layout.addWidget(top_bar_widget)
        main_layout.addLayout(tables_stack)
        main_layout.addStretch(1)
        main_layout.addWidget(bottom_bar_widget)
        main_layout.addWidget(stop_bar)

    @staticmethod
    def _load_pixmap(path: str, height: int) -> QPixmap:
        pm = QPixmap(path)
        return pm.scaledToHeight(height, Qt.SmoothTransformation) if not pm.isNull() else QPixmap()

    def open_menu(self):
        self.menu_window = MenuWindow(self)
        self.menu_window.start_button.clicked.connect(self.start_market_maker_from_menu)
        self.menu_window.show()

    def start_market_maker_from_menu(self):
        asset = self.menu_window.asset_dropdown.currentText()

        levels_text = self.menu_window.levels_input.text()
        range_text = self.menu_window.range_input.text()
        scalp_text = self.menu_window.scalp_input.text()
        amount_text = self.menu_window.amount_input.text()

        if not asset or not levels_text or not range_text or not scalp_text or not amount_text:
            print("Missing asset, levels, range, scalp, or amount.")
            return

        try:
            levels = int(levels_text.strip())
            range_pct = float(range_text.replace("%", "").strip())
            scalp_pct = float(scalp_text.replace("%", "").strip())
            total_amount = float(amount_text.replace("$", "").strip())
        except ValueError:
            print("Levels must be an integer. Range, Scalp, and Amount must be numbers.")
            return

        if levels <= 0 or range_pct <= 0 or scalp_pct <= 0 or total_amount <= 0:
            print("Levels, Range, Scalp, and Amount must be greater than zero.")
            return

        market = self.menu_window.asset_market_map.get(asset)

        self.setWindowTitle(f"{asset}/USD")

        self.engine.start(
            asset=asset,
            market=market,
            levels=levels,
            range_pct=range_pct,
            scalp_pct=scalp_pct,
            total_amount=total_amount
        )

        self.menu_window.close()

    def on_price_update(self, last, bid, ask, high, low, change, volume, timestamp):
        self.value_label.setText(f"{last:,.2f}")
        self.pricing_table.set_price(last)
        self.heartbeat_label.setText(timestamp)

        self.lbl_high.setText(f"{high:,.0f}")
        self.lbl_change.setText(f"{change:.2f}%")
        self.lbl_low.setText(f"{low:,.0f}")
        self.lbl_volume.setText(f"{volume:,.0f}")

        self.ask_ladder.update_ask_ladder(ask, self.exit_orders)
        self.best_bid_table.update_bid_ladder(bid, self.enter_orders)

    def on_net_update(self, net):
        self.lbl_net.setText(f"{net:.8f}")

    def on_exit_orders_update(self, exit_orders):
        self.exit_orders = exit_orders

    def on_enter_orders_update(self, enter_orders):
        self.enter_orders = enter_orders

    def on_accumulation_update(self, qty):
        self.lbl_pl.setText(f"{qty:.8f}")

    def stop_market_maker(self):
        self.engine.stop()
        self.heartbeat_label.setText("STOPPED")


def main():
    app = QApplication(sys.argv)
    win = MarketMakerWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()


# -*- coding: utf-8

import json
import requests
import sys

def send_to_anki(method, params):
    try: 
        r = requests.post("http://127.0.0.1:8765", data=json.dumps({"action": method, "version": 5, "params": params}))
        return json.loads(r.text)
    except requests.exceptions.ConnectionError:
        return False

def create_deck_if_not_exists(deck):
    ret = send_to_anki("changeDeck", {"cards": [], "deck": deck })
    return ret

def add_anki_card(deck, model, fields):
    params = {
        "note": {
            "deckName": deck,
            "modelName": model,
            "fields": json.loads(fields)
        }
    }
    return send_to_anki("addNote", params)

def main():
    deck = sys.argv[1]
    model = sys.argv[2]
    fields = sys.argv[3]

    ret = create_deck_if_not_exists(deck)

    if ret == False:
        return False
    else:
        return add_anki_card(deck, model, fields)

if __name__ == '__main__':
    ret = main()

    if ret != False and ret["result"] != None:
        sys.exit(0)
    else:
        sys.exit(1)

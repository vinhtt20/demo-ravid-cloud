from flask import Flask, jsonify

app = Flask(__name__)
# 4. Trigger workflow

@app.get("/healthz")
def healthz():
    return jsonify(status="ok"), 200

@app.get("/")
def root():
    return "ok", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

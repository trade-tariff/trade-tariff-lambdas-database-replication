import json
import subprocess

print("Loading my function")


def handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    subprocess.run("bash restore.sh".split(" "))
    print("Process complete.")
    return 0

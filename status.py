#!/usr/bin/env python3
"""Latest deployment status per service. Usage: status.py <projectId> [--logs svc] [--events svc]"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path("~/.claude/skills/create-template-for-railway/scripts").expanduser()))
import rw  # noqa: E402

pid = sys.argv[1]
# Service.deployments now answers "Not Authorized"; the top-level query still works.
edges = rw.gql("""query($id:String!){deployments(first:40,input:{projectId:$id}){edges{node{id status createdAt
  service{name}}}}}""", {"id": pid})["deployments"]["edges"]
latest = {}
for e in sorted(edges, key=lambda e: e["node"]["createdAt"]):
    latest[e["node"]["service"]["name"]] = e["node"]
for name, dep in latest.items():
    print(f"{name:10} {dep['status']} {dep['id']}")
for flag in ("--logs", "--events"):
    if flag in sys.argv:
        dep = latest[sys.argv[sys.argv.index(flag) + 1]]
        if flag == "--logs":
            logs = rw.gql("query($d:String!){deploymentLogs(deploymentId:$d,limit:80){message}}", {"d": dep["id"]})
            print("\n".join(l["message"] for l in logs["deploymentLogs"]))
        else:
            ev = rw.gql("query($d:String!){deploymentEvents(id:$d){edges{node{step payload{error reason detail}}}}}",
                        {"d": dep["id"]})
            for e in ev["deploymentEvents"]["edges"]:
                print(e["node"])

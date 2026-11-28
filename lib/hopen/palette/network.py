"""The Network group of the command palette."""
from . import then_wait


def items(ctx):
    ctx.add("ports", "Network", "Show the ports that your programs listen on", "hopen --ports")


ACTIONS = {"ports": lambda ctx, action: then_wait(ctx.self_path, "--ports")}

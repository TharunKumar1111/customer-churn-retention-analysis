"""Tiny notebook executor: runs cells in order, captures stdout, last-expression values and matplotlib figures,
and writes a standard .ipynb (nbformat 4) WITH outputs so GitHub renders it. (Used because Jupyter isn't installed here;
on your machine simply open the .ipynb in Jupyter / VS Code and 'Run All'.)"""
import ast, io, json, base64, contextlib, os, sys, traceback, uuid
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

def run(cells, out_path, workdir):
    os.chdir(workdir); ns={"__name__":"__main__"}; nb_cells=[]; count=0
    for kind,src in cells:
        src=src.strip("\n")
        if kind=="md":
            nb_cells.append({"cell_type":"markdown","id":uuid.uuid4().hex[:8],"metadata":{},"source":src.splitlines(True)}); continue
        count+=1; outputs=[]; buf=io.StringIO(); last=None
        tree=ast.parse(src)
        try:
            body=tree.body; expr=None
            if body and isinstance(body[-1],ast.Expr): expr=ast.Expression(body.pop().value)
            with contextlib.redirect_stdout(buf):
                exec(compile(ast.Module(body,[]),"<cell>","exec"),ns)
                if expr is not None: last=eval(compile(expr,"<cell>","eval"),ns)
        except Exception:
            print("ERROR in cell",count); print(src[:300]); traceback.print_exc(); raise
        if buf.getvalue(): outputs.append({"output_type":"stream","name":"stdout","text":buf.getvalue().splitlines(True)})
        for num in plt.get_fignums():
            b=io.BytesIO(); plt.figure(num).savefig(b,format="png",dpi=110,bbox_inches="tight")
            outputs.append({"output_type":"display_data","metadata":{},"data":{"image/png":base64.b64encode(b.getvalue()).decode(),"text/plain":["<Figure>"]}})
        plt.close("all")
        if last is not None:
            data={"text/plain":repr(last).splitlines(True)}
            if isinstance(last,(pd.DataFrame,pd.Series)):
                data["text/plain"]=last.to_string().splitlines(True)
                if isinstance(last,pd.DataFrame): data["text/html"]=last.to_html(max_rows=40).splitlines(True)
            outputs.append({"output_type":"execute_result","execution_count":count,"metadata":{},"data":data})
        nb_cells.append({"cell_type":"code","id":uuid.uuid4().hex[:8],"metadata":{},"execution_count":count,"source":src.splitlines(True),"outputs":outputs})
    nb={"cells":nb_cells,"metadata":{"kernelspec":{"display_name":"Python 3","language":"python","name":"python3"},"language_info":{"name":"python"}},"nbformat":4,"nbformat_minor":5}
    json.dump(nb,open(out_path,"w"),indent=1)
    return ns

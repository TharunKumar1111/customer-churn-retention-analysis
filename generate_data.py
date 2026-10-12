"""Generates a SYNTHETIC telecom (broadband + mobile) customer dataset with realistic churn drivers and some data-quality problems."""
import numpy as np, pandas as pd, os
rng=np.random.default_rng(11); N=7200
OUT=os.path.join(os.path.dirname(__file__),"..","data"); os.makedirs(OUT,exist_ok=True)
regions={"North":["Delhi","Lucknow","Chandigarh","Jaipur"],"South":["Bengaluru","Chennai","Hyderabad","Kochi"],"West":["Mumbai","Pune","Ahmedabad","Surat"],"East":["Kolkata","Bhubaneswar","Patna","Guwahati"]}
rw=[.22,.32,.28,.18]
reg=rng.choice(list(regions),N,p=rw); city=[rng.choice(regions[r]) for r in reg]
signup=pd.to_datetime("2026-09-30")-pd.to_timedelta(rng.integers(30,72*30,N),unit="D")
tenure=((pd.Timestamp("2026-09-30")-signup).days//30).astype(int)
senior=rng.random(N)<.16; partner=rng.random(N)<.48; dep=(rng.random(N)<.28)&partner|(rng.random(N)<.06)
contract=np.where(rng.random(N)<np.clip(.35+tenure/160,0,.9),rng.choice(["One year","Two year"],N,p=[.45,.55]),"Month-to-month")
internet=rng.choice(["Fiber optic","DSL","No internet"],N,p=[.44,.34,.22])
def addon(p): return np.where(internet=="No internet","No internet service",np.where(rng.random(N)<p,"Yes","No"))
sec=addon(.36); backup=addon(.40); prot=addon(.40); tech=addon(.33); tv=addon(.42); mov=addon(.42)
phone=rng.random(N)<.9
pay=rng.choice(["Electronic check","Mailed check","Bank transfer","Credit card"],N,p=[.34,.20,.23,.23]); paperless=rng.random(N)<np.where(pay=="Electronic check",.75,.5)
base=np.where(internet=="Fiber optic",70,np.where(internet=="DSL",45,20))+phone*8
mc=base+(sec=="Yes")*5+(backup=="Yes")*5+(prot=="Yes")*5+(tech=="Yes")*6+(tv=="Yes")*9+(mov=="Yes")*9+rng.normal(0,4,N)
mc=np.round(np.clip(mc,18,125),2)
tickets=rng.poisson(np.clip(0.6+0.8*(internet=="Fiber optic")+0.5*(tech=="No")-0.002*tenure,.1,4)); late=rng.poisson(np.where(pay=="Electronic check",1.0,.4))
usage=np.round(np.where(internet=="No internet",0,rng.gamma(4,28,N)*np.where(internet=="Fiber optic",1.6,1)),1)
z=(-2.0+1.25*(contract=="Month-to-month")-0.9*(contract=="Two year")+0.55*(internet=="Fiber optic")-0.025*tenure
   +0.012*(mc-65)+0.28*tickets+0.25*late+0.45*(tech=="No")*(internet!="No internet")+0.35*(pay=="Electronic check")
   +0.25*senior+0.2*paperless-0.2*partner-0.3*dep-0.2*(sec=="Yes")+rng.normal(0,.55,N))
p=1/(1+np.exp(-z)); churn=rng.random(N)<p
# churned customers' tenure counts until they left (already tenure) - keep as is
mc=np.round(mc*10,0)
total=np.round(mc*tenure*rng.uniform(.96,1.0,N),2)
df=pd.DataFrame({"customer_id":[f"CUST{100000+i}" for i in range(N)],"signup_date":signup.strftime("%Y-%m-%d"),"gender":rng.choice(["Male","Female"],N),
 "senior_citizen":senior.astype(int),"partner":np.where(partner,"Yes","No"),"dependents":np.where(dep,"Yes","No"),"region":reg,"city":city,
 "tenure_months":tenure,"contract":contract,"payment_method":pay,"paperless_billing":np.where(paperless,"Yes","No"),"phone_service":np.where(phone,"Yes","No"),
 "internet_service":internet,"online_security":sec,"online_backup":backup,"device_protection":prot,"tech_support":tech,"streaming_tv":tv,"streaming_movies":mov,
 "monthly_charges":mc,"total_charges":total,"avg_monthly_data_gb":usage,"support_tickets_6m":tickets,"late_payments_12m":late,"churn":np.where(churn,"Yes","No")})
print("churn rate",churn.mean().round(3))
# ---- dirty version ----
raw=df.copy(); log={}
i=rng.choice(N,int(N*.02),replace=False); raw.loc[i,"total_charges"]=np.nan; log["missing total_charges"]=len(i)
i=rng.choice(N,int(N*.03),replace=False); raw.loc[i,"contract"]=[c.lower() for c in raw.loc[i,"contract"]]; log["contract text in lowercase"]=len(i)
i=rng.choice(N,int(N*.02),replace=False); raw.loc[i,"payment_method"]=[" "+c+" " for c in raw.loc[i,"payment_method"]]; log["payment_method extra spaces"]=len(i)
i=rng.choice(N,40,replace=False); raw.loc[i,"monthly_charges"]=-raw.loc[i,"monthly_charges"]; log["negative monthly_charges"]=len(i)
i=rng.choice(N,int(N*.015),replace=False); raw.loc[i,"gender"]=np.nan; log["missing gender"]=len(i)
d=raw.sample(60,random_state=3); raw=pd.concat([raw,d]); log["duplicate customer rows"]=len(d)
raw=raw.sample(frac=1,random_state=2).reset_index(drop=True)
raw.to_csv(f"{OUT}/telecom_churn_raw.csv",index=False); pd.Series(log).to_csv(f"{OUT}/raw_issue_log.csv",header=["rows"])
print(log,len(raw))

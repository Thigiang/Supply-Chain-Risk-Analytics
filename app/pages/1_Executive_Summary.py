from pathlib import Path

import streamlit as st

SUMMARY_PATH = Path(__file__).parent.parent / "executive_summary.md"

st.set_page_config(page_title="Executive Summary", layout="wide")
st.title("Executive summary")
st.caption("For operations managers. Written with Claude from the dashboard's SQL results on 2026-10-21.")

st.markdown(SUMMARY_PATH.read_text())

with st.expander("How this summary was produced"):
    st.markdown(
        "The six dashboard queries in `sql/dashboard/` were run against the database, and Claude wrote "
        "the summary from those results using only their numbers. Every figure was then checked against "
        "the query output. The dataset is fixed, so the summary is stored in `app/executive_summary.md` "
        "instead of being generated live, which needs no API key."
    )

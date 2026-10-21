from pathlib import Path

import streamlit as st

SUMMARY_PATH = Path(__file__).parent.parent / "executive_summary.md"

st.set_page_config(page_title="Executive Summary", layout="wide")
st.title("Executive summary")
st.caption("For operations managers. Written with Claude from the dashboard's SQL results on 2026-10-21.")

st.markdown(SUMMARY_PATH.read_text())
